<#
  Извлечение реального каталога pro-tek.pro:
  меню, дерево категорий, по N товаров в каждую категорию и подкатегорию,
  фотографии товаров и наличие по складам.

  Результат: _source\catalog.json  +  assets\img\products\*
#>

param(
  [int]$PerCat   = 5,
  [int]$DelayMs  = 150,
  [switch]$SkipImages
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root   = Split-Path -Parent $PSScriptRoot
$src    = Join-Path $root '_source'
$imgOut = Join-Path $root 'assets\img\products'
New-Item -ItemType Directory -Force -Path $src, $imgOut | Out-Null

$BASE = 'https://pro-tek.pro'
$H = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        'Accept-Language' = 'ru-RU,ru;q=0.9' }

function Get-Page([string]$url) {
  for ($i = 0; $i -lt 3; $i++) {
    try { return (Invoke-WebRequest -Uri $url -UseBasicParsing -Headers $H -TimeoutSec 40).Content }
    catch { Start-Sleep -Milliseconds 800 }
  }
  return $null
}
function Clean([string]$s) {
  if (-not $s) { return '' }
  $s = $s -replace '(?s)<[^>]+>', ' '
  $s = [System.Net.WebUtility]::HtmlDecode($s)
  return ($s -replace '\s+', ' ').Trim()
}

# ============================================================
# 1. Главная -> верхнее меню и дерево каталога
# ============================================================
Write-Host 'Читаю главную...' -ForegroundColor Cyan
$homeHtml = Get-Page "$BASE/"
if (-not $homeHtml) { Write-Host 'Главная недоступна. Проверьте VPN.' -ForegroundColor Red; exit 1 }
[IO.File]::WriteAllText((Join-Path $src 'home.html'), $homeHtml, [Text.Encoding]::UTF8)

# --- верхнее меню ---
$topMenu = New-Object System.Collections.ArrayList
foreach ($m in [regex]::Matches($homeHtml, '(?s)<li class="main-menu-btn[^"]*">(.*?)(?=<li class="main-menu-btn|</ul>\s*</div>\s*</div>\s*</div>)')) {
  $blk = $m.Groups[1].Value
  if ($blk -match '<a[^>]+class="[^"]*main-menu-btn-link[^"]*"[^>]+href="([^"]+)"[^>]*>(.*?)</a>') {
    $url = $matches[1]; $name = Clean $matches[2]
    if (-not $name) { continue }
    $subs = New-Object System.Collections.ArrayList
    foreach ($s in [regex]::Matches($blk, '(?s)<li class="submenu-item[^2][^"]*">\s*<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>')) {
      [void]$subs.Add([pscustomobject]@{ name = (Clean $s.Groups[2].Value); url = $s.Groups[1].Value })
    }
    [void]$topMenu.Add([pscustomobject]@{ name = $name; url = $url; sub = $subs })
  }
}

# --- дерево каталога из мега-меню ---
$catBlockStart = $homeHtml.IndexOf('main-menu-catalog')
$catBlock = $homeHtml.Substring($catBlockStart)
$idx = [regex]::Matches($catBlock, '<li class="submenu-item(?!2)[^"]*">')
$cats = New-Object System.Collections.ArrayList

for ($i = 0; $i -lt $idx.Count; $i++) {
  $from = $idx[$i].Index
  $to   = if ($i + 1 -lt $idx.Count) { $idx[$i + 1].Index } else { [Math]::Min($from + 40000, $catBlock.Length) }
  $slice = $catBlock.Substring($from, $to - $from)

  if ($slice -notmatch '(?s)<a[^>]+href="(/catalog/cid/[^"]+)"[^>]*>(.*?)</a>') { continue }
  $curl = $matches[1]; $inner = $matches[2]
  $cname = if ($inner -match '(?s)<span>(.*?)</span>') { Clean $matches[1] } else { Clean $inner }
  if (-not $cname) { continue }
  $cicon = if ($slice -match "<img src='([^']+)'") { $matches[1] } elseif ($slice -match '<img src="([^"]+)"') { $matches[1] } else { '' }

  $subs = New-Object System.Collections.ArrayList
  foreach ($s in [regex]::Matches($slice, '(?s)<li class="submenu-item2[^"]*">\s*<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>')) {
    $sn = Clean $s.Groups[2].Value
    if ($sn) { [void]$subs.Add([pscustomobject]@{ name = $sn; url = $s.Groups[1].Value; products = @() }) }
  }
  [void]$cats.Add([pscustomobject]@{ name = $cname; url = $curl; icon = $cicon; sub = $subs; products = @() })
}

Write-Host ("Категорий: {0}, подкатегорий: {1}" -f $cats.Count, (($cats | ForEach-Object { $_.sub.Count }) | Measure-Object -Sum).Sum) -ForegroundColor Green

# ============================================================
# 2. Товары
# ============================================================
$imgSeen = @{}
$prodCount = 0

function Get-Products([string]$pageUrl, [int]$limit) {
  $html = Get-Page ($BASE + $pageUrl)
  if (-not $html) { return @() }
  $out = New-Object System.Collections.ArrayList

  $starts = [regex]::Matches($html, '<div class="col-lg-4 col-md-4 col-sm-6 col-xs-12 effect" data-id="(\d+)">')
  for ($i = 0; $i -lt $starts.Count -and $out.Count -lt $limit; $i++) {
    $from = $starts[$i].Index
    $to   = if ($i + 1 -lt $starts.Count) { $starts[$i + 1].Index } else { [Math]::Min($from + 20000, $html.Length) }
    $card = $html.Substring($from, $to - $from)
    $id   = $starts[$i].Groups[1].Value

    $name = if ($card -match '(?s)<div class="item-name[^"]*">\s*<a[^>]*>(.*?)</a>') { Clean $matches[1] } else { '' }
    if (-not $name) { continue }
    $href = if ($card -match '<a href="(/catalog/\d+\.html)"') { $matches[1] } else { "/catalog/$id.html" }
    $img  = if ($card -match '<div class="item-image">\s*<img[^>]+src="([^"]+)"') { $matches[1] } else { '' }
    $price = if ($card -match '(?s)<div class="item-price">(.*?)</div>') { Clean $matches[1] } else { '' }

    $stock = New-Object System.Collections.ArrayList
    foreach ($a in [regex]::Matches($card, '<div class="item-avail-(stock|order)">([^<]+)</div>')) {
      [void]$stock.Add([pscustomobject]@{ city = (Clean $a.Groups[2].Value); state = $a.Groups[1].Value })
    }

    # --- фото ---
    $localImg = ''
    if ($img -and -not $SkipImages) {
      if ($imgSeen.ContainsKey($img)) { $localImg = $imgSeen[$img] }
      else {
        $ext = [IO.Path]::GetExtension(($img -split '\?')[0]); if (-not $ext) { $ext = '.png' }
        $fn  = "$id$ext"
        try {
          Invoke-WebRequest -Uri ($BASE + $img) -UseBasicParsing -Headers $H -TimeoutSec 30 -OutFile (Join-Path $imgOut $fn)
          $localImg = "assets/img/products/$fn"
          $imgSeen[$img] = $localImg
        } catch { }
      }
    }

    [void]$out.Add([pscustomobject]@{
      id = $id; name = $name; url = $href; price = $price
      img = $localImg; imgSrc = $img; stock = $stock
    })
  }
  Start-Sleep -Milliseconds $DelayMs
  return $out.ToArray()
}

$total = $cats.Count + (($cats | ForEach-Object { $_.sub.Count }) | Measure-Object -Sum).Sum
$done = 0

foreach ($c in $cats) {
  $done++
  Write-Host ("[{0,3}/{1}] {2}" -f $done, $total, $c.name)
  $c.products = Get-Products $c.url $PerCat
  $prodCount += $c.products.Count
  foreach ($s in $c.sub) {
    $done++
    Write-Host ("[{0,3}/{1}]    - {2}" -f $done, $total, $s.name)
    $s.products = Get-Products $s.url $PerCat
    $prodCount += $s.products.Count
  }
}

# ============================================================
# 3. Сохранение
# ============================================================
$result = [pscustomobject]@{
  source     = $BASE
  fetchedAt  = (Get-Date).ToString('yyyy-MM-dd HH:mm')
  topMenu    = $topMenu
  categories = $cats
}
$json = $result | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText((Join-Path $src 'catalog.json'), $json, [Text.Encoding]::UTF8)

Write-Host ''
Write-Host 'Готово.' -ForegroundColor Green
Write-Host ("  категорий:  {0}" -f $cats.Count)
Write-Host ("  товаров:    {0}" -f $prodCount)
Write-Host ("  картинок:   {0}" -f $imgSeen.Count)
Write-Host ("  json:       {0}" -f (Join-Path $src 'catalog.json'))
