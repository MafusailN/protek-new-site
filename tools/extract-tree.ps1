<#
  Extract catalog tree (categories + subcategories) from pro-tek.pro home page.
  Output: _source\tree.json
#>
param([switch]$Live)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root '_source'
New-Item -ItemType Directory -Force -Path $src | Out-Null

$H = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        'Accept-Language' = 'ru-RU,ru;q=0.9' }

if ($Live) {
  Write-Host 'Fetching live home page...' -ForegroundColor Cyan
  $html = (Invoke-WebRequest -Uri 'https://pro-tek.pro/' -UseBasicParsing -Headers $H -TimeoutSec 40).Content
  [IO.File]::WriteAllText((Join-Path $src 'home.html'), $html, [Text.Encoding]::UTF8)
} else {
  $html = [IO.File]::ReadAllText((Join-Path $src 'pages\index.html'))
}

function Clean([string]$s) {
  if (-not $s) { return '' }
  $s = $s -replace '(?s)<[^>]+>', ' '
  $s = [System.Net.WebUtility]::HtmlDecode($s)
  return ($s -replace '\s+', ' ').Trim()
}

# ---- isolate the catalog mega-menu block ----
$start = $html.IndexOf('main-menu-catalog')
if ($start -lt 0) { Write-Host 'catalog menu not found' -ForegroundColor Red; exit 1 }
# menu ends where the next top-level main-menu-btn begins
$rest = $html.Substring($start + 20)
$endRel = $rest.IndexOf('<li class="main-menu-btn')
if ($endRel -lt 0) { $endRel = [Math]::Min(400000, $rest.Length) }
$block = $rest.Substring(0, $endRel)

# ---- top-level categories ----
$marks = [regex]::Matches($block, '<li class="submenu-item(?!2)[^"]*">')
$cats = New-Object System.Collections.ArrayList

for ($i = 0; $i -lt $marks.Count; $i++) {
  $from = $marks[$i].Index
  $to   = if ($i + 1 -lt $marks.Count) { $marks[$i + 1].Index } else { $block.Length }
  $slice = $block.Substring($from, $to - $from)

  if ($slice -notmatch '(?s)<a[^>]*href="(/catalog/cid/[^"]+)"[^>]*>(.*?)</a>') { continue }
  $curl = $matches[1]; $inner = $matches[2]
  $cname = if ($inner -match '(?s)<span>(.*?)</span>') { Clean $matches[1] } else { Clean $inner }
  if (-not $cname) { continue }
  $cicon = if ($slice -match "<img\s+src='([^']+)'") { $matches[1] }
           elseif ($slice -match '<img\s+src="([^"]+)"') { $matches[1] } else { '' }

  $subs = New-Object System.Collections.ArrayList
  foreach ($s in [regex]::Matches($slice, '(?s)<li class="submenu-item2[^"]*">\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>')) {
    $sn = Clean $s.Groups[2].Value
    if ($sn) { [void]$subs.Add([pscustomobject]@{ name = $sn; url = $s.Groups[1].Value }) }
  }
  [void]$cats.Add([pscustomobject]@{ name = $cname; url = $curl; icon = $cicon; sub = $subs })
}

# ---- top menu (non-catalog nav items) ----
$topMenu = New-Object System.Collections.ArrayList
foreach ($m in [regex]::Matches($html, '<a class="effect main-menu-btn-link" href="([^"]+)">([^<]*)</a>')) {
  $n = Clean $m.Groups[2].Value
  if ($n) { [void]$topMenu.Add([pscustomobject]@{ name = $n; url = $m.Groups[1].Value }) }
}

$subTotal = (($cats | ForEach-Object { $_.sub.Count }) | Measure-Object -Sum).Sum
Write-Host ("categories: {0}  subcategories: {1}  topmenu: {2}" -f $cats.Count, $subTotal, $topMenu.Count) -ForegroundColor Green

$out = [pscustomobject]@{
  source = 'https://pro-tek.pro'
  fetchedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')
  topMenu = $topMenu
  categories = $cats
}
[IO.File]::WriteAllText((Join-Path $src 'tree.json'), ($out | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
Write-Host ("saved: " + (Join-Path $src 'tree.json'))

foreach ($c in $cats) { Write-Host ("  {0}  [{1}]  {2}" -f $c.name, $c.sub.Count, $c.url) }
