<#
  Fetch products for every category and subcategory listed in _source\tree.json.
  Saves _source\catalog.json and product images into assets\img\products.
#>
param(
  [int]$PerNode  = 8,
  [int]$DelayMs  = 120,
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

$tree = Get-Content (Join-Path $src 'tree.json') -Raw -Encoding UTF8 | ConvertFrom-Json

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

$imgSeen  = @{}
$allProds = @{}
$stat = [pscustomobject]@{ pages = 0; prods = 0; imgs = 0; empty = 0 }

function Get-Products([string]$pageUrl, [int]$limit) {
  $html = Get-Page ($BASE + $pageUrl)
  if (-not $html) { return @() }
  $script:stat.pages++

  $out = New-Object System.Collections.ArrayList
  $starts = [regex]::Matches($html, '<div class="col-lg-4 col-md-4 col-sm-6 col-xs-12 effect" data-id="(\d+)">')

  for ($i = 0; $i -lt $starts.Count -and $out.Count -lt $limit; $i++) {
    $from = $starts[$i].Index
    $to   = if ($i + 1 -lt $starts.Count) { $starts[$i + 1].Index } else { [Math]::Min($from + 20000, $html.Length) }
    $card = $html.Substring($from, $to - $from)
    $id   = $starts[$i].Groups[1].Value

    $name = if ($card -match '(?s)<div class="item-name[^"]*">\s*<a[^>]*>(.*?)</a>') { Clean $matches[1] } else { '' }
    if (-not $name) { continue }

    $href  = if ($card -match '<a href="(/catalog/[^"]+\.html)"') { $matches[1] } else { '' }
    $img   = if ($card -match '(?s)<div class="item-image">\s*<img[^>]+src="([^"]+)"') { $matches[1] } else { '' }
    $price = if ($card -match '(?s)<div class="item-price">(.*?)</div>\s*<div class="item-cart') { Clean $matches[1] }
             elseif ($card -match '(?s)<div class="item-price">(.*?)</div>') { Clean $matches[1] } else { '' }

    $stock = New-Object System.Collections.ArrayList
    foreach ($a in [regex]::Matches($card, '<div class="item-avail-(stock|order)">([^<]+)</div>')) {
      [void]$stock.Add([pscustomobject]@{ city = (Clean $a.Groups[2].Value); state = $a.Groups[1].Value })
    }

    # image download (shared cache across whole run)
    $localImg = ''
    if ($img -and -not $SkipImages) {
      if ($imgSeen.ContainsKey($img)) { $localImg = $imgSeen[$img] }
      else {
        $ext = [IO.Path]::GetExtension(($img -split '\?')[0])
        if (-not $ext -or $ext.Length -gt 5) { $ext = '.png' }
        $fn = "$id$ext"
        try {
          Invoke-WebRequest -Uri ($BASE + $img) -UseBasicParsing -Headers $H -TimeoutSec 25 -OutFile (Join-Path $imgOut $fn)
          $localImg = "assets/img/products/$fn"
          $imgSeen[$img] = $localImg
          $script:stat.imgs++
        } catch { }
      }
    }

    $p = [pscustomobject]@{
      id = $id; name = $name; url = $href; price = $price
      img = $localImg; stock = $stock
    }
    [void]$out.Add($p)
    $script:allProds[$id] = $p
  }
  Start-Sleep -Milliseconds $DelayMs
  return ,$out.ToArray()
}

$total = $tree.categories.Count + (($tree.categories | ForEach-Object { $_.sub.Count }) | Measure-Object -Sum).Sum
$done = 0
$result = New-Object System.Collections.ArrayList

foreach ($c in $tree.categories) {
  $done++
  $cp = Get-Products $c.url $PerNode
  $stat.prods += $cp.Count
  if ($cp.Count -lt 5) { $stat.empty++ }
  Write-Host ("[{0,3}/{1}] {2} -> {3}" -f $done, $total, $c.name, $cp.Count)

  $subsOut = New-Object System.Collections.ArrayList
  foreach ($s in $c.sub) {
    $done++
    $sp = Get-Products $s.url $PerNode
    $stat.prods += $sp.Count
    if ($sp.Count -lt 5) { $stat.empty++ }
    Write-Host ("[{0,3}/{1}]    - {2} -> {3}" -f $done, $total, $s.name, $sp.Count)
    [void]$subsOut.Add([pscustomobject]@{ name = $s.name; url = $s.url; products = $sp })
  }

  [void]$result.Add([pscustomobject]@{
    name = $c.name; url = $c.url; icon = $c.icon
    products = $cp; sub = $subsOut
  })
}

$outObj = [pscustomobject]@{
  source     = $BASE
  fetchedAt  = (Get-Date).ToString('yyyy-MM-dd HH:mm')
  topMenu    = $tree.topMenu
  categories = $result
}
[IO.File]::WriteAllText((Join-Path $src 'catalog.json'), ($outObj | ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)

Write-Host ''
Write-Host 'DONE' -ForegroundColor Green
Write-Host ("  pages fetched : {0}" -f $stat.pages)
Write-Host ("  product slots : {0}" -f $stat.prods)
Write-Host ("  unique prods  : {0}" -f $allProds.Count)
Write-Host ("  images        : {0}" -f $stat.imgs)
Write-Host ("  nodes under 5 : {0}" -f $stat.empty)
