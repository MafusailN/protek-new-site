<#
  Пересобирает подборку товаров для каждого раздела и подраздела.

  Со страницы раздела снимаются ВСЕ карточки, затем отбираются лучшие
  по приоритету (сверху вниз):

    1. есть цена  +  наличие во всех городах
    2. есть цена  +  наличие в меньшем числе городов
    3. есть цена  +  нет в наличии нигде
    4. цена по запросу, но есть фотография
    5. всё остальное — в последнюю очередь

  Дополнительно снимаются метки товара («Распродажа», «Рекомендуем»,
  «Спецпредложение») из блока item-tags.

  Результат: _source\catalog.json (прежний файл сохраняется как catalog-old.json)
#>

param(
  [int]$Per = 5,
  [int]$DelayMs = 150,
  [switch]$SkipImages
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root   = Split-Path -Parent $PSScriptRoot
$src    = Join-Path $root '_source'
$imgOut = Join-Path $root 'assets\img\products'
New-Item -ItemType Directory -Force -Path $imgOut | Out-Null

$BASE = 'https://pro-tek.pro'
$H = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        'Accept-Language' = 'ru-RU,ru;q=0.9' }

function Get-Page([string]$url) {
  for ($i = 0; $i -lt 3; $i++) {
    try { return (Invoke-WebRequest -Uri $url -UseBasicParsing -Headers $H -TimeoutSec 40).Content }
    catch { Start-Sleep -Milliseconds 700 }
  }
  return $null
}
function Clean([string]$s) {
  if (-not $s) { return '' }
  $s = $s -replace '(?s)<[^>]+>', ' '
  $s = [System.Net.WebUtility]::HtmlDecode($s)
  return ($s -replace '\s+', ' ').Trim()
}
function HasPrice([string]$t) {
  if (-not $t) { return $false }
  return ($t -match '\d') -and ($t -notmatch '(?i)по\s*запросу')
}

# ---------- разбор одной страницы раздела ----------
function Read-Cards([string]$nodeUrl) {
  $html = Get-Page ($BASE + $nodeUrl)
  if (-not $html) { return @() }
  $out = New-Object System.Collections.ArrayList

  $starts = [regex]::Matches($html, '<div class="col-lg-4 col-md-4 col-sm-6 col-xs-12 effect" data-id="(\d+)">')
  for ($i = 0; $i -lt $starts.Count; $i++) {
    $from = $starts[$i].Index
    $to   = if ($i + 1 -lt $starts.Count) { $starts[$i + 1].Index } else { [Math]::Min($from + 20000, $html.Length) }
    $card = $html.Substring($from, $to - $from)
    $id   = $starts[$i].Groups[1].Value

    $name = if ($card -match '(?s)<div class="item-name[^"]*">\s*<a[^>]*>(.*?)</a>') { Clean $matches[1] } else { '' }
    if (-not $name) { continue }
    $href  = if ($card -match '<a href="(/catalog/\d+\.html)"') { $matches[1] } else { "/catalog/$id.html" }
    $imgSrc = if ($card -match '<div class="item-image">\s*<img[^>]+src="([^"]+)"') { $matches[1] } else { '' }
    $price  = if ($card -match '(?s)<div class="item-price">(.*?)</div>') { Clean $matches[1] } else { '' }

    $stock = New-Object System.Collections.ArrayList
    foreach ($a in [regex]::Matches($card, '<div class="item-avail-(stock|order)">([^<]+)</div>')) {
      [void]$stock.Add([pscustomobject]@{ city = (Clean $a.Groups[2].Value); state = $a.Groups[1].Value })
    }

    # метки товара: Распродажа / Рекомендуем / Спецпредложение
    $tags = New-Object System.Collections.ArrayList
    if ($card -match '(?s)<div class="item-tags">(.*?)</div>\s*<a') {
      foreach ($t in [regex]::Matches($matches[1], '<div class="item-tags-([a-z0-9_-]+)"[^>]*>([^<]+)</div>')) {
        [void]$tags.Add([pscustomobject]@{ kind = $t.Groups[1].Value; text = (Clean $t.Groups[2].Value) })
      }
    }

    $inStock = ($stock | Where-Object { $_.state -eq 'stock' }).Count
    $hasPic  = $imgSrc -and ($imgSrc -notmatch 'no-photo')

    [void]$out.Add([pscustomobject]@{
      id = $id; name = $name; url = $href; price = $price; imgSrc = $imgSrc
      stock = $stock; tags = $tags
      inStock = $inStock; hasPrice = (HasPrice $price); hasPic = [bool]$hasPic
    })
  }
  Start-Sleep -Milliseconds $DelayMs
  return $out.ToArray()
}

# ---------- отбор ----------
function Pick([object[]]$cards, [int]$n) {
  if (-not $cards -or -not $cards.Count) { return @() }
  # чем больше вес, тем выше товар в списке
  $scored = $cards | ForEach-Object {
    $w = 0
    if ($_.hasPrice) { $w += 10000 }      # цена важнее всего: «по запросу» отбрасываем
    $w += $_.inStock * 100                # затем — в скольких городах есть
    if ($_.hasPic)  { $w += 10 }          # при прочих равных — с фотографией
    $_ | Add-Member -NotePropertyName rank -NotePropertyValue $w -Force -PassThru
  }
  return ($scored | Sort-Object -Property @{Expression='rank';Descending=$true}, @{Expression='id';Descending=$false} | Select-Object -First $n)
}

# ---------- загрузка фотографий выбранных ----------
$imgSeen = @{}
function Fetch-Img($p) {
  if ($SkipImages -or -not $p.imgSrc -or $p.imgSrc -match 'no-photo') { return '' }
  if ($imgSeen.ContainsKey($p.imgSrc)) { return $imgSeen[$p.imgSrc] }
  $ext = [IO.Path]::GetExtension(($p.imgSrc -split '\?')[0]); if (-not $ext -or $ext.Length -gt 5) { $ext = '.png' }
  $fn = "$($p.id)$ext"
  try {
    Invoke-WebRequest -Uri ($BASE + $p.imgSrc) -UseBasicParsing -Headers $H -TimeoutSec 30 -OutFile (Join-Path $imgOut $fn)
    $imgSeen[$p.imgSrc] = "assets/img/products/$fn"
    return $imgSeen[$p.imgSrc]
  } catch { return '' }
}

function ToStored($p) {
  [pscustomobject]@{
    id = $p.id; name = $p.name; url = $p.url; price = $p.price
    img = (Fetch-Img $p); imgSrc = $p.imgSrc; stock = $p.stock; tags = $p.tags
  }
}

# ============================================================
$old = Get-Content (Join-Path $src 'catalog.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Copy-Item (Join-Path $src 'catalog.json') (Join-Path $src 'catalog-old.json') -Force

$nodes = 0
foreach ($c in $old.categories) { $nodes++; $nodes += $c.sub.Count }
$done = 0
$stat = [pscustomobject]@{ full = 0; priced = 0; onreq = 0; nopic = 0; empty = 0 }

foreach ($c in $old.categories) {
  $done++
  $cards = Read-Cards $c.url
  $sel = Pick $cards $Per
  $c.products = @($sel | ForEach-Object { ToStored $_ })
  Write-Host ("[{0,3}/{1}] {2} — из {3} выбрано {4}" -f $done, $nodes, $c.name, $cards.Count, $c.products.Count)

  foreach ($p in $sel) {
    if ($p.hasPrice -and $p.inStock -ge 6) { $stat.full++ }
    elseif ($p.hasPrice) { $stat.priced++ }
    elseif ($p.hasPic) { $stat.onreq++ }
    else { $stat.nopic++ }
  }
  if (-not $sel.Count) { $stat.empty++ }

  foreach ($s in $c.sub) {
    $done++
    $cs = Read-Cards $s.url
    $ss = Pick $cs $Per
    $s.products = @($ss | ForEach-Object { ToStored $_ })
    Write-Host ("[{0,3}/{1}]    - {2} — из {3} выбрано {4}" -f $done, $nodes, $s.name, $cs.Count, $s.products.Count)
    foreach ($p in $ss) {
      if ($p.hasPrice -and $p.inStock -ge 6) { $stat.full++ }
      elseif ($p.hasPrice) { $stat.priced++ }
      elseif ($p.hasPic) { $stat.onreq++ }
      else { $stat.nopic++ }
    }
    if (-not $ss.Count) { $stat.empty++ }
  }
}

$old.fetchedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')
[IO.File]::WriteAllText((Join-Path $src 'catalog.json'), ($old | ConvertTo-Json -Depth 9), [Text.Encoding]::UTF8)

Write-Host ''
Write-Host 'Готово.' -ForegroundColor Green
Write-Host ("  с ценой и наличием во всех городах: {0}" -f $stat.full)
Write-Host ("  с ценой, наличие частичное:         {0}" -f $stat.priced)
Write-Host ("  цена по запросу, но с фото:         {0}" -f $stat.onreq)
Write-Host ("  без цены и без фото:                {0}" -f $stat.nopic)
Write-Host ("  узлов без товаров:                  {0}" -f $stat.empty)
