<#
  Выгрузка pro-tek.pro для последующей сборки нового сайта.
  Запуск: правой кнопкой -> "Выполнить с помощью PowerShell"
  либо в консоли:  powershell -ExecutionPolicy Bypass -File .\fetch-site.ps1

  Ничего никуда не отправляет — только скачивает страницы и картинки
  в папку _source рядом с проектом.
#>

param(
  [string]$Start    = "https://pro-tek.pro/",
  [int]$MaxPages    = 400,
  [int]$MaxImages   = 1200,
  [int]$DelayMs     = 250
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root    = Split-Path -Parent $PSScriptRoot
$src     = Join-Path $root '_source'
$pageDir = Join-Path $src 'pages'
$imgDir  = Join-Path $src 'img'
New-Item -ItemType Directory -Force -Path $pageDir, $imgDir | Out-Null

$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
$headers = @{ "User-Agent" = $UA; "Accept-Language" = "ru-RU,ru;q=0.9" }

$host0   = ([Uri]$Start).Host
$queue   = [System.Collections.Generic.Queue[string]]::new()
$seen    = [System.Collections.Generic.HashSet[string]]::new()
$imgSeen = [System.Collections.Generic.HashSet[string]]::new()
$map     = New-Object System.Collections.ArrayList
$imgMap  = New-Object System.Collections.ArrayList

# затравка: главная + каталог
foreach ($u in @($Start, ($Start.TrimEnd('/') + '/catalog/'))) {
  if ($seen.Add($u)) { $queue.Enqueue($u) }
}

function Get-SafeName([string]$url) {
  $p = ([Uri]$url).AbsolutePath.Trim('/')
  if ([string]::IsNullOrWhiteSpace($p)) { $p = 'index' }
  $q = ([Uri]$url).Query
  if ($q) { $p += '_' + ($q.TrimStart('?')) }
  $p = $p -replace '[^\w\-\.]+', '_'
  if ($p.Length -gt 120) { $p = $p.Substring(0, 120) + '_' + ($url.GetHashCode() -band 0xffff) }
  return $p
}

function Resolve-Url([string]$base, [string]$href) {
  try {
    if ($href -match '^(mailto:|tel:|javascript:|#|data:)') { return $null }
    return ([Uri]::new([Uri]$base, $href)).GetLeftPart([UriPartial]::Query)
  } catch { return $null }
}

Write-Host "Скачиваю $Start ..." -ForegroundColor Cyan
$pages = 0

while ($queue.Count -gt 0 -and $pages -lt $MaxPages) {
  $url = $queue.Dequeue()
  try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -Headers $headers -TimeoutSec 30
  } catch {
    Write-Host "  пропуск $url ($($_.Exception.Message))" -ForegroundColor DarkYellow
    continue
  }
  $ct = "$($r.Headers['Content-Type'])"
  if ($ct -and $ct -notmatch 'text/html') { continue }

  $pages++
  $name = Get-SafeName $url
  $file = Join-Path $pageDir "$name.html"
  [IO.File]::WriteAllText($file, $r.Content, [Text.Encoding]::UTF8)
  [void]$map.Add([pscustomobject]@{ url = $url; file = "pages/$name.html" })
  Write-Host ("[{0,3}/{1}] {2}" -f $pages, $MaxPages, $url)

  $html = $r.Content

  # --- картинки (включая lazy-load атрибуты) ---
  $imgMatches = [regex]::Matches($html, '(?:src|data-src|data-original|data-lazy|srcset)\s*=\s*["'']([^"''>]+)["'']', 'IgnoreCase')
  foreach ($m in $imgMatches) {
    if ($imgSeen.Count -ge $MaxImages) { break }
    $raw = ($m.Groups[1].Value -split ',')[0].Trim() -replace '\s+\d+[wx]$', ''
    if ($raw -notmatch '\.(jpe?g|png|webp|gif|svg)(\?|$)') { continue }
    $abs = Resolve-Url $url $raw
    if (-not $abs) { continue }
    if (([Uri]$abs).Host -ne $host0) { continue }
    if (-not $imgSeen.Add($abs)) { continue }

    $iname = Get-SafeName $abs
    $ext = [IO.Path]::GetExtension(([Uri]$abs).AbsolutePath)
    if (-not $ext) { $ext = '.jpg' }
    $ipath = Join-Path $imgDir "$iname"
    if (-not $ipath.EndsWith($ext)) { $ipath += $ext }
    try {
      Invoke-WebRequest -Uri $abs -UseBasicParsing -Headers $headers -TimeoutSec 30 -OutFile $ipath
      [void]$imgMap.Add([pscustomobject]@{ url = $abs; file = "img/" + (Split-Path $ipath -Leaf); page = $url })
    } catch { }
  }

  # --- ссылки: идём вглубь каталога и по основным разделам ---
  foreach ($m in [regex]::Matches($html, 'href\s*=\s*["'']([^"''>]+)["'']', 'IgnoreCase')) {
    $abs = Resolve-Url $url $m.Groups[1].Value
    if (-not $abs) { continue }
    if (([Uri]$abs).Host -ne $host0) { continue }
    if ($abs -match '\.(jpe?g|png|webp|gif|svg|pdf|zip|rar|doc|xls|exe)(\?|$)') { continue }
    if ($abs -match '(\?|&)(PAGEN|sort|order|view|set_filter|bitrix|login|register|basket|compare)') { continue }
    if ($seen.Add($abs)) { $queue.Enqueue($abs) }
  }

  Start-Sleep -Milliseconds $DelayMs
}

$map    | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $src 'pages.json') -Encoding UTF8
$imgMap | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $src 'images.json') -Encoding UTF8

Write-Host ""
Write-Host "Готово." -ForegroundColor Green
Write-Host "  страниц:  $pages"
Write-Host "  картинок: $($imgMap.Count)"
Write-Host "  папка:    $src"
Write-Host ""
Write-Host "Теперь скажите Claude: «выгрузка готова, папка _source»." -ForegroundColor Cyan
