<#
  Второй проход: карточки товаров из _source\catalog.json.
  Снимает реальные бренд, артикулы, описание, характеристики,
  наличие по городам со сроками и полноразмерное фото.

  Результат: _source\details.json + assets\img\products-lg\*
#>

param(
  [int]$DelayMs = 120,
  [switch]$SkipImages
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root   = Split-Path -Parent $PSScriptRoot
$src    = Join-Path $root '_source'
$imgOut = Join-Path $root 'assets\img\products-lg'
New-Item -ItemType Directory -Force -Path $imgOut | Out-Null

$BASE = 'https://pro-tek.pro'
$H = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        'Accept-Language' = 'ru-RU,ru;q=0.9' }

function Get-Page([string]$url) {
  for ($i = 0; $i -lt 3; $i++) {
    try { return (Invoke-WebRequest -Uri $url -UseBasicParsing -Headers $H -TimeoutSec 35).Content }
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

$cat = Get-Content (Join-Path $src 'catalog.json') -Raw -Encoding UTF8 | ConvertFrom-Json

# --- собрать уникальные товары ---
$targets = @{}
foreach ($c in $cat.categories) {
  foreach ($p in $c.products) { if ($p.id) { $targets[[string]$p.id] = $p.url } }
  foreach ($s in $c.sub) { foreach ($p in $s.products) { if ($p.id) { $targets[[string]$p.id] = $p.url } } }
}
$ids = $targets.Keys | Sort-Object
Write-Host ("Карточек к обходу: {0}" -f $ids.Count) -ForegroundColor Cyan

$details = @{}
$n = 0; $okSpecs = 0; $okImg = 0

foreach ($id in $ids) {
  $n++
  $url = $targets[$id]
  if (-not $url) { $url = "/catalog/$id.html" }
  $html = Get-Page ($BASE + $url)
  if (-not $html) { Write-Host ("[{0,4}/{1}] {2} — не открылась" -f $n, $ids.Count, $id) -ForegroundColor DarkYellow; continue }

  # бренд
  $brand = ''
  if ($html -match '(?s)<div class="item-brend">.*?<a[^>]*>(.*?)<') { $brand = Clean $matches[1] }

  # артикулы
  $artM = ''; $artC = ''
  foreach ($m in [regex]::Matches($html, '<div class="item-text-code">([^<]+)</div>')) {
    $t = Clean $m.Groups[1].Value
    if ($t -match '(?i)артикул производителя\s*:\s*(.+)$') { $artM = $matches[1].Trim() }
    elseif ($t -match '(?i)код товара\s*:\s*(.+)$') { $artC = $matches[1].Trim() }
  }

  # краткое описание
  $preview = ''
  if ($html -match '(?s)<div class="item-text-preview">(.*?)</div>') { $preview = Clean $matches[1] }

  # характеристики (только из блока item-property-list)
  $specs = New-Object System.Collections.ArrayList
  # блок характеристик есть только у основного товара — карусель похожих его не содержит,
  # поэтому ищем по всей странице: попытка сузить область обрезала часть параметров
  foreach ($m in [regex]::Matches($html, '(?s)<div class="item-property-name">\s*<span>(.*?)</span>.*?<div class="item-property-value">\s*<span>(.*?)</span>')) {
    $k = Clean $m.Groups[1].Value; $v = Clean $m.Groups[2].Value
    if ($k -and $v) { [void]$specs.Add(@($k, $v)) }
  }
  if ($specs.Count) { $okSpecs++ }

  # наличие: первые 6 пар — основной товар
  $avail = New-Object System.Collections.ArrayList
  foreach ($m in [regex]::Matches($html, '<div class="item-avail-name">([^<]+)</div>\s*<div class="item-avail-(stock|order)">([^<]*)</div>')) {
    if ($avail.Count -ge 6) { break }
    [void]$avail.Add([pscustomobject]@{
      city = (Clean $m.Groups[1].Value); state = $m.Groups[2].Value; term = (Clean $m.Groups[3].Value)
    })
  }

  # фотографии из блока галереи карточки
  $big = ''
  $shots = New-Object System.Collections.ArrayList
  $galScope = ''
  $gi = $html.IndexOf('class="item-images"')
  if ($gi -ge 0) { $galScope = $html.Substring($gi, [Math]::Min(1500, $html.Length - $gi)) }

  $srcs = New-Object System.Collections.ArrayList
  foreach ($m in [regex]::Matches($galScope, 'src="([^"]+)"')) { [void]$srcs.Add($m.Groups[1].Value) }
  # прямые ссылки на оригиналы, если они есть в разметке
  foreach ($m in [regex]::Matches($html, '/files/import/[^"''\s>]+\.(?:png|jpe?g|webp)')) { [void]$srcs.Add($m.Value) }

  $seenShot = @{}
  foreach ($s in $srcs) {
    if ($s -match 'no-photo') { continue }          # заглушка «нет фото» — не берём
    $orig = $s
    # из кэш-URL восстанавливаем путь к оригиналу
    if ($s -match '__files_import_(.+?)\.(png|jpe?g|webp)(?:_.*)?$') { $orig = "/files/import/$($matches[1]).$($matches[2])" }
    elseif ($s -notmatch '^/files/') { continue }
    if ($seenShot.ContainsKey($orig)) { continue }
    $seenShot[$orig] = 1

    if ($SkipImages) { [void]$shots.Add($orig); continue }
    $ext = [IO.Path]::GetExtension(($orig -split '\?')[0]); if (-not $ext -or $ext.Length -gt 5) { $ext = '.jpg' }
    $fn = if ($shots.Count -eq 0) { "$id$ext" } else { "$id-$($shots.Count)$ext" }
    try {
      Invoke-WebRequest -Uri ($BASE + $orig) -UseBasicParsing -Headers $H -TimeoutSec 30 -OutFile (Join-Path $imgOut $fn)
      [void]$shots.Add("assets/img/products-lg/$fn")
      $okImg++
    } catch { }
  }
  if ($shots.Count) { $big = $shots[0] }

  $details[$id] = [pscustomobject]@{
    id = $id; brand = $brand; artManuf = $artM; artCode = $artC
    preview = $preview; specs = $specs.ToArray(); avail = $avail.ToArray()
    imgBig = $big; shots = $shots.ToArray()
  }

  if ($n % 25 -eq 0 -or $n -eq $ids.Count) {
    Write-Host ("[{0,4}/{1}] характеристик: {2}, фото: {3}" -f $n, $ids.Count, $okSpecs, $okImg)
  }
  Start-Sleep -Milliseconds $DelayMs
}

$outObj = [pscustomobject]@{ fetchedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm'); items = $details }
[IO.File]::WriteAllText((Join-Path $src 'details.json'), ($outObj | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)

Write-Host ''
Write-Host 'Готово.' -ForegroundColor Green
Write-Host ("  карточек:          {0}" -f $details.Count)
Write-Host ("  с характеристиками:{0}" -f $okSpecs)
Write-Host ("  больших фото:      {0}" -f $okImg)
