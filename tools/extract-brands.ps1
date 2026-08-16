<#
  Бренды с pro-tek.pro: логотип, название, число товаров, ссылка.
  Результат: _source\brands.json + assets\img\brands\*
#>

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root   = Split-Path -Parent $PSScriptRoot
$src    = Join-Path $root '_source'
$imgOut = Join-Path $root 'assets\img\brands'
New-Item -ItemType Directory -Force -Path $imgOut | Out-Null

$BASE = 'https://pro-tek.pro'
$hdr = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
          'Accept-Language' = 'ru-RU,ru;q=0.9' }

$page = (Invoke-WebRequest "$BASE/catalog/brends/" -UseBasicParsing -Headers $hdr -TimeoutSec 40).Content
[IO.File]::WriteAllText((Join-Path $src 'brands.html'), $page, [Text.Encoding]::UTF8)

$out = New-Object System.Collections.ArrayList
$seen = @{}
$ok = 0

foreach ($m in [regex]::Matches($page, '(?s)<a[^>]+href="(/catalog/brends/bid/([^/"]+)/)"[^>]*>(.*?)</a>')) {
  $url = $m.Groups[1].Value
  $slug = $m.Groups[2].Value
  if ($seen.ContainsKey($slug)) { continue }
  $inner = $m.Groups[3].Value

  $txt = (($inner -replace '<[^>]+>', ' ') -replace '\s+', ' ').Trim()
  $name = $txt; $count = 0
  if ($txt -match '^(.*?)\s*/\s*(\d+)$') { $name = $matches[1].Trim(); $count = [int]$matches[2] }
  if (-not $name) { continue }
  $seen[$slug] = 1

  $logo = ''
  if ($inner -match 'src="([^"]+)"') {
    $srcUrl = $matches[1]
    if ($srcUrl -notmatch 'no-photo') {
      $orig = $srcUrl
      if ($srcUrl -match '__files_flib_(.+?)\.(png|jpe?g|webp)(?:_.*)?$') { $orig = "/files/flib/$($matches[1]).$($matches[2])" }
      $ext = [IO.Path]::GetExtension(($orig -split '\?')[0]); if (-not $ext -or $ext.Length -gt 5) { $ext = '.png' }
      try {
        Invoke-WebRequest -Uri ($BASE + $orig) -UseBasicParsing -Headers $hdr -TimeoutSec 25 -OutFile (Join-Path $imgOut "$slug$ext")
        $logo = "assets/img/brands/$slug$ext"; $ok++
      } catch { }
    }
  }

  [void]$out.Add([pscustomobject]@{ slug = $slug; name = $name; count = $count; url = $url; logo = $logo })
  Start-Sleep -Milliseconds 60
}

$res = [pscustomobject]@{ fetchedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm'); brands = $out.ToArray() }
[IO.File]::WriteAllText((Join-Path $src 'brands.json'), ($res | ConvertTo-Json -Depth 5), [Text.Encoding]::UTF8)

Write-Host 'Готово.' -ForegroundColor Green
Write-Host ("  брендов:    {0}" -f $out.Count)
Write-Host ("  логотипов:  {0}" -f $ok)
