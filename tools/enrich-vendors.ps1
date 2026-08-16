<#
  Дообогащение каталога с сайтов производителей:
  дополнительные фотографии и технические характеристики.

  Главный принцип — строгая сверка артикула. Товар засчитывается только
  если артикул на сайте производителя ПОЛНОСТЬЮ совпадает с нашим.
  Частичное совпадение (PR08.3940 против PR08.39400) отбрасывается.

  Результат: _source\vendor.json + assets\img\vendor\<id>-N.<ext>
#>

param(
  [string[]]$Brands = @('Промрукав'),
  [int]$Limit = 0,
  [int]$DelayMs = 400,
  [switch]$SkipImages
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root   = Split-Path -Parent $PSScriptRoot
$src    = Join-Path $root '_source'
$imgOut = Join-Path $root 'assets\img\vendor'
New-Item -ItemType Directory -Force -Path $imgOut | Out-Null

$hdr = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
          'Accept-Language' = 'ru-RU,ru;q=0.9' }

function Get-Page([string]$url) {
  for ($i = 0; $i -lt 2; $i++) {
    try { return (Invoke-WebRequest -Uri $url -UseBasicParsing -Headers $hdr -TimeoutSec 30).Content }
    catch { Start-Sleep -Milliseconds 600 }
  }
  return $null
}
function Clean([string]$s) {
  if (-not $s) { return '' }
  $s = $s -replace '(?s)<[^>]+>', ' '
  $s = [System.Net.WebUtility]::HtmlDecode($s)
  return ($s -replace '\s+', ' ').Trim()
}
function NormArt([string]$s) {
  if (-not $s) { return '' }
  return ($s -replace '[\s ]', '').ToUpperInvariant()
}

# ============================================================
#  Адаптеры производителей
#  Каждый умеет: найти кандидатов по артикулу и разобрать карточку.
# ============================================================
$ADAPTERS = @{

  'Промрукав' = @{
    site   = 'https://promrukav.ru'
    search = { param($art) "https://promrukav.ru/search/?q=$([Uri]::EscapeDataString($art))" }
    links  = {
      param($html)
      $i = $html.IndexOf('search-result')
      if ($i -lt 0) { return @() }
      $blk = $html.Substring($i, [Math]::Min(20000, $html.Length - $i))
      [regex]::Matches($blk, 'href="(/catalog/[^"]+/[^"]+/)"') |
        ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique | Select-Object -First 5
    }
    parse  = {
      param($html)
      $art = ''
      if ($html -match '(?s)<div class="prop artnumber">\s*<span>[^<]*</span>\s*<span>(.*?)</span>') { $art = Clean $matches[1] }
      $specs = New-Object System.Collections.ArrayList
      $ti = $html.IndexOf('properties-table')
      if ($ti -ge 0) {
        $tbl = $html.Substring($ti, [Math]::Min(20000, $html.Length - $ti))
        foreach ($m in [regex]::Matches($tbl, '(?s)<div class="name">(.*?)</div>\s*<div class="value">(.*?)</div>')) {
          $k = Clean $m.Groups[1].Value; $v = Clean $m.Groups[2].Value
          if ($k -and $v -and $k -notmatch '(?i)^(бренд|штрихкод|артикул)$') { [void]$specs.Add(@($k, $v)) }
        }
      }
      $imgs = New-Object System.Collections.ArrayList
      foreach ($m in [regex]::Matches($html, 'class="detail-gallery"\s+data-href="([^"]+)"')) { [void]$imgs.Add($m.Groups[1].Value) }
      foreach ($m in [regex]::Matches($html, 'data-href="(/upload/iblock/[^"]+\.(?:jpg|jpeg|png|webp))"')) {
        if ($imgs -notcontains $m.Groups[1].Value) { [void]$imgs.Add($m.Groups[1].Value) }
      }
      return @{ art = $art; specs = $specs.ToArray(); imgs = $imgs.ToArray() }
    }
  }
}

# ============================================================
$dataFile = Join-Path $root 'assets\js\data.js'
$js = [IO.File]::ReadAllText($dataFile, [Text.Encoding]::UTF8)

$targets = New-Object System.Collections.ArrayList
foreach ($line in ($js -split "`n")) {
  if ($line -notmatch '^\s*\{ id: "') { continue }
  if ($line -notmatch 'id: "(\d+)"') { continue }
  $pid2 = $matches[1]
  if ($line -notmatch 'b: "((?:[^"\\]|\\.)*)"') { continue }
  $b = $matches[1]
  if ($Brands -notcontains $b) { continue }
  if ($line -notmatch 'art: "((?:[^"\\]|\\.)*)"') { continue }   # без артикула сверять нечего
  $a = $matches[1]
  $nm = ''
  if ($line -match 'n: "((?:[^"\\]|\\.)*)"') { $nm = $matches[1] }
  [void]$targets.Add([pscustomobject]@{ id = $pid2; name = $nm; brand = $b; art = $a })
}
if ($Limit -gt 0 -and $targets.Count -gt $Limit) { $targets = $targets[0..($Limit - 1)] }

Write-Host ("Товаров к обогащению: {0}" -f $targets.Count) -ForegroundColor Cyan
if (-not $targets.Count) { Write-Host 'Нет позиций с артикулом для указанных брендов.' -ForegroundColor Yellow; exit }

# уже собранное — не теряем между запусками
$store = @{}
$vendorFile = Join-Path $src 'vendor.json'
if (Test-Path $vendorFile) {
  $old = Get-Content $vendorFile -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($k in $old.items.PSObject.Properties) { $store[$k.Name] = $k.Value }
}

$stat = [pscustomobject]@{ tried = 0; matched = 0; specs = 0; imgs = 0; nomatch = 0 }

foreach ($t in $targets) {
  $stat.tried++
  $ad = $ADAPTERS[$t.brand]
  if (-not $ad) { continue }

  $searchUrl = & $ad.search $t.art
  $sHtml = Get-Page $searchUrl
  if (-not $sHtml) { $stat.nomatch++; continue }

  $cands = & $ad.links $sHtml
  $hit = $null
  foreach ($c in $cands) {
    $pHtml = Get-Page ($ad.site + $c)
    if (-not $pHtml) { continue }
    $info = & $ad.parse $pHtml
    if ((NormArt $info.art) -eq (NormArt $t.art)) { $hit = $info; $hit.url = $ad.site + $c; break }
    Start-Sleep -Milliseconds 120
  }

  if (-not $hit) {
    $stat.nomatch++
    Write-Host ("[{0,3}/{1}] {2} — точного совпадения нет" -f $stat.tried, $targets.Count, $t.art) -ForegroundColor DarkYellow
    Start-Sleep -Milliseconds $DelayMs
    continue
  }

  $stat.matched++
  if ($hit.specs.Count) { $stat.specs++ }

  # фотографии
  $shots = New-Object System.Collections.ArrayList
  if (-not $SkipImages) {
    $k = 0
    foreach ($im in $hit.imgs) {
      if ($k -ge 4) { break }
      $ext = [IO.Path]::GetExtension(($im -split '\?')[0]); if (-not $ext -or $ext.Length -gt 5) { $ext = '.jpg' }
      $fn = "$($t.id)-v$k$ext"
      try {
        Invoke-WebRequest -Uri ($ad.site + $im) -UseBasicParsing -Headers $hdr -TimeoutSec 25 -OutFile (Join-Path $imgOut $fn)
        [void]$shots.Add("assets/img/vendor/$fn"); $stat.imgs++; $k++
      } catch { }
    }
  }

  $store[$t.id] = [pscustomobject]@{
    id = $t.id; brand = $t.brand; art = $t.art; url = $hit.url
    specs = $hit.specs; shots = $shots.ToArray()
  }

  Write-Host ("[{0,3}/{1}] {2} — характеристик {3}, фото {4}" -f `
    $stat.tried, $targets.Count, $t.art, $hit.specs.Count, $shots.Count) -ForegroundColor Green
  Start-Sleep -Milliseconds $DelayMs
}

$res = [pscustomobject]@{ fetchedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm'); items = $store }
[IO.File]::WriteAllText($vendorFile, ($res | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)

Write-Host ''
Write-Host 'Готово.' -ForegroundColor Green
Write-Host ("  проверено:            {0}" -f $stat.tried)
Write-Host ("  найдено по артикулу:  {0}" -f $stat.matched)
Write-Host ("  из них с параметрами: {0}" -f $stat.specs)
Write-Host ("  скачано фотографий:   {0}" -f $stat.imgs)
Write-Host ("  совпадений нет:       {0}" -f $stat.nomatch)
Write-Host ("  файл:                 {0}" -f $vendorFile)
