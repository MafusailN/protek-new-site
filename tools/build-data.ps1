<#
  Build assets\js\data.js from _source\catalog.json.
  Guarantees at least $MinPer products in every category and subcategory
  by topping up short nodes with real products from the parent branch.
#>
param([int]$MinPer = 5)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root '_source'
$cat  = Get-Content (Join-Path $src 'catalog.json') -Raw -Encoding UTF8 | ConvertFrom-Json

$CITIES = @('Новосибирск','Барнаул','Кемерово','Новокузнецк','Томск','Красноярск')

function Slugify([string]$url) {
  if ($url -match '/catalog/cid/([^/]+)/') { return $matches[1] }
  return ($url -replace '[^\w]+','-').Trim('-')
}
function ParsePrice([string]$t) {
  if (-not $t) { return 'null' }
  $s = $t -replace '\s',''
  if ($s -match '(\d+[\.,]?\d*)\s*Р') { return ($matches[1] -replace ',','.') }
  if ($s -match '^(\d+[\.,]?\d*)') { return ($matches[1] -replace ',','.') }
  return 'null'
}
function Brand([string]$name) {
  $known = @('Dahua','Hikvision','HiWatch','RVi','Beward','Bolid','Болид','Rubetek','TRASSIR','ATIS','Optimus',
             'Tantos','Активиссима','PERCo','Sigur','ZKTeco','Ps-Link','Legrand','DKC','ABB','IEK','EKF',
             'Schneider','TP-Link','Ubiquiti','MikroTik','D-Link','SNR','Cisco','Rittal','ЦМО','Hyperline',
             'Netko','Паритет','Крепёж','SKAT','Бастион','Teplocom','APC','Ippon','Rapan','Аргус','Смартек',
             'Nedap','Came','Nice','FAAC','DoorHan','An-Motors','Roger','Praktica','Falcon','Инкотекс')
  foreach ($b in $known) { if ($name -match [regex]::Escape($b)) { return $b } }
  if ($name -match '^([A-Z][A-Za-z\-]{2,})') { return $matches[1] }
  return 'PROTECH'
}
function JsStr([string]$s) {
  if ($null -eq $s) { return '""' }
  $s = $s -replace '\\','\\' -replace '"','\"' -replace "`r",'' -replace "`n",' '
  return '"' + $s + '"'
}
function StockJs($stock) {
  # map site availability to a per-city state: 1 = in stock, 0 = on order
  $map = @{}
  foreach ($s in $stock) { if ($s.city) { $map[$s.city] = $(if ($s.state -eq 'stock') { 1 } else { 0 }) } }
  $vals = foreach ($c in $CITIES) { if ($map.ContainsKey($c)) { $map[$c] } else { 0 } }
  return '[' + ($vals -join ',') + ']'
}

# ---------- детали карточек (второй проход) ----------
$DET = @{}
$detPath = Join-Path $src 'details.json'
if (Test-Path $detPath) {
  $d = Get-Content $detPath -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($k in $d.items.PSObject.Properties) { $DET[$k.Name] = $k.Value }
  Write-Host ("details.json: {0} карточек" -f $DET.Count) -ForegroundColor DarkGray
}

# ---------- данные с сайтов производителей ----------
$VEND = @{}
$vendPath = Join-Path $src 'vendor.json'
if (Test-Path $vendPath) {
  $v = Get-Content $vendPath -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($k in $v.items.PSObject.Properties) { $VEND[$k.Name] = $k.Value }
  Write-Host ("vendor.json: {0} карточек" -f $VEND.Count) -ForegroundColor DarkGray
}

# ---------- выбор лучшего снимка ----------
Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
$dimCache = @{}
function PixCount([string]$rel) {
  if (-not $rel) { return 0 }
  if ($dimCache.ContainsKey($rel)) { return $dimCache[$rel] }
  $full = Join-Path $root ($rel -replace '/', '\')
  $n = 0
  if (Test-Path $full) {
    try { $b = [System.Drawing.Bitmap]::FromFile($full); $n = $b.Width * $b.Height; $b.Dispose() } catch { $n = 0 }
  }
  $dimCache[$rel] = $n
  return $n
}

function JsSpecs($specs) {
  if (-not $specs) { return '' }
  $parts = foreach ($s in $specs) { '[' + (JsStr $s[0]) + ',' + (JsStr $s[1]) + ']' }
  return '[' + ($parts -join ',') + ']'
}
function JsAvail($av) {
  if (-not $av) { return '' }
  $parts = foreach ($a in $av) { '{c:' + (JsStr $a.city) + ',s:' + (JsStr $a.state) + ',t:' + (JsStr $a.term) + '}' }
  return '[' + ($parts -join ',') + ']'
}

# ---------- collect unique products ----------
$prodIndex = @{}   # id -> product object
$order     = New-Object System.Collections.ArrayList

function Reg($p, $catId, $subId) {
  if (-not $p -or -not $p.id) { return $null }
  $id = [string]$p.id
  if (-not $prodIndex.ContainsKey($id)) {
    $det = $DET[$id]
    # бренд берём реальный с карточки, эвристика по названию — только запасной вариант
    $brand = if ($det -and $det.brand) { $det.brand } else { Brand $p.name }
    # на сайте у части товаров фото нет — отдаётся общая заглушка no-photo.
    # такие позиции показываем без картинки, а не с чужим файлом
    $img = $p.img
    if ($p.imgSrc -and $p.imgSrc -match 'no-photo') { $img = '' }

    # «крупный» снимок иногда оказывается мельче карточного — берём тот, что больше
    $bigRel = $(if ($det) { $det.imgBig } else { '' })
    if ($bigRel -and $img -and (PixCount $bigRel) -lt (PixCount $img)) { $bigRel = '' }

    $obj = [pscustomobject]@{
      id = $id; name = $p.name; url = $p.url; price = (ParsePrice $p.price)
      priceText = $p.price; img = $img; stock = (StockJs $p.stock)
      brand = $brand; cat = $catId; sub = $subId
      art = $(if ($det) { $det.artManuf } else { '' })
      code = $(if ($det) { $det.artCode } else { '' })
      prev = $(if ($det) { $det.preview } else { '' })
      big  = $bigRel
      specs = $(if ($det) { $det.specs } else { $null })
      avail = $(if ($det) { $det.avail } else { $null })
      tags = $p.tags
      vspecs = $(if ($VEND.ContainsKey($id)) { $VEND[$id].specs } else { $null })
      vshots = $(if ($VEND.ContainsKey($id)) { $VEND[$id].shots } else { $null })
      vurl   = $(if ($VEND.ContainsKey($id)) { $VEND[$id].url } else { '' })
    }
    $prodIndex[$id] = $obj
    [void]$order.Add($obj)
  }
  return $id
}

$catsOut = New-Object System.Collections.ArrayList

foreach ($c in $cat.categories) {
  $cid = Slugify $c.url
  $ownIds = New-Object System.Collections.ArrayList
  foreach ($p in $c.products) { $id = Reg $p $cid ''; if ($id) { [void]$ownIds.Add($id) } }

  # pool for topping up: category products + every subcategory product
  $pool = New-Object System.Collections.ArrayList
  foreach ($id in $ownIds) { [void]$pool.Add($id) }

  $subsOut = New-Object System.Collections.ArrayList
  foreach ($s in $c.sub) {
    $sid = Slugify $s.url
    $ids = New-Object System.Collections.ArrayList
    foreach ($p in $s.products) { $id = Reg $p $cid $sid; if ($id) { [void]$ids.Add($id) } }
    foreach ($id in $ids) { if (-not $pool.Contains($id)) { [void]$pool.Add($id) } }
    [void]$subsOut.Add([pscustomobject]@{ id = $sid; name = $s.name; url = $s.url; ids = $ids })
  }

  # top up subcategories that have fewer than $MinPer
  foreach ($s in $subsOut) {
    if ($s.ids.Count -ge $MinPer) { continue }
    foreach ($id in $pool) {
      if ($s.ids.Count -ge $MinPer) { break }
      if (-not $s.ids.Contains($id)) { [void]$s.ids.Add($id) }
    }
  }
  # top up the category itself
  if ($ownIds.Count -lt $MinPer) {
    foreach ($id in $pool) {
      if ($ownIds.Count -ge $MinPer) { break }
      if (-not $ownIds.Contains($id)) { [void]$ownIds.Add($id) }
    }
  }

  [void]$catsOut.Add([pscustomobject]@{
    id = $cid; name = $c.name; url = $c.url; icon = $c.icon
    ids = $ownIds; sub = $subsOut
  })
}

# ---------- emit data.js ----------
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('/* ============================================================')
[void]$sb.AppendLine('   PROTECH - каталог, снятый с pro-tek.pro')
[void]$sb.AppendLine('   Сгенерировано tools\build-data.ps1 - вручную не править.')
[void]$sb.AppendLine(('   Источник: {0}   снято: {1}' -f $cat.source, $cat.fetchedAt))
[void]$sb.AppendLine('   ============================================================ */')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('const CITIES = [' + (($CITIES | ForEach-Object { JsStr $_ }) -join ', ') + '];')
[void]$sb.AppendLine('')

# ---------- верхнее меню: разбираем главную страницу как есть ----------
$menu = New-Object System.Collections.ArrayList
$homeFile = Join-Path $src 'home.html'
if (Test-Path $homeFile) {
  $homeHtml = [IO.File]::ReadAllText($homeFile, [Text.Encoding]::UTF8)
  $starts = [regex]::Matches($homeHtml, '<li class="main-menu-btn[^"]*">')
  for ($i = 0; $i -lt $starts.Count; $i++) {
    $from = $starts[$i].Index
    $to = if ($i + 1 -lt $starts.Count) { $starts[$i + 1].Index } else { [Math]::Min($from + 60000, $homeHtml.Length) }
    $blk = $homeHtml.Substring($from, $to - $from)

    $lm = [regex]::Match($blk, '(?s)<a class="effect main-menu-btn-link" href="([^"]+)"[^>]*>(.*?)</a>')
    if (-not $lm.Success) { continue }
    $mUrl = $lm.Groups[1].Value
    $mName = (($lm.Groups[2].Value -replace '<[^>]+>', '') -replace '\s+', ' ').Trim()
    if (-not $mName) { continue }

    $subs = New-Object System.Collections.ArrayList
    foreach ($s in [regex]::Matches($blk, '(?s)<li class="submenu-item(?!2)[^"]*">\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>')) {
      $sn = (($s.Groups[2].Value -replace '<[^>]+>', ' ') -replace '\s+', ' ').Trim()
      if ($sn) { [void]$subs.Add([pscustomobject]@{ name = $sn; url = $s.Groups[1].Value }) }
    }
    [void]$menu.Add([pscustomobject]@{ name = $mName; url = $mUrl; sub = $subs })
  }
}
if (-not $menu.Count -and $cat.topMenu) { foreach ($m in $cat.topMenu) { [void]$menu.Add($m) } }

# ---------- бренды с логотипами ----------
$brandsPath = Join-Path $src 'brands.json'
if (Test-Path $brandsPath) {
  $bj = Get-Content $brandsPath -Raw -Encoding UTF8 | ConvertFrom-Json
  [void]$sb.AppendLine('const BRANDS = [')
  foreach ($b in $bj.brands) {
    [void]$sb.AppendLine('  { slug: ' + (JsStr $b.slug) + ', name: ' + (JsStr $b.name) +
      ', n: ' + $b.count + ', logo: ' + (JsStr $b.logo) + ' },')
  }
  [void]$sb.AppendLine('];')
  [void]$sb.AppendLine('const BLOGO = {};')
  [void]$sb.AppendLine('BRANDS.forEach(b => { BLOGO[b.name.toLowerCase()] = b; });')
  [void]$sb.AppendLine('')
  Write-Host ("бренды: {0}" -f $bj.brands.Count) -ForegroundColor DarkGray
} else {
  [void]$sb.AppendLine('const BRANDS = []; const BLOGO = {};')
  [void]$sb.AppendLine('')
}

[void]$sb.AppendLine('const MENU = [')
foreach ($m in $menu) {
  $subs = ''
  # у «Каталога» подменю рисуется отдельным мега-меню — дубликат в шапке не нужен
  if ($m.url -ne '/catalog/' -and $m.sub -and $m.sub.Count) {
    $parts = foreach ($s in $m.sub) { '{ name: ' + (JsStr $s.name) + ', url: ' + (JsStr $s.url) + ' }' }
    $subs = ($parts -join ', ')
  }
  [void]$sb.AppendLine('  { name: ' + (JsStr $m.name) + ', url: ' + (JsStr $m.url) + ', sub: [' + $subs + '] },')
}
[void]$sb.AppendLine('];')
[void]$sb.AppendLine('')
Write-Host ("меню: {0} пунктов" -f $menu.Count) -ForegroundColor DarkGray

# products
[void]$sb.AppendLine('const PRODUCTS = [')
foreach ($p in $order) {
  $extra = ''
  if ($p.art)  { $extra += ', art: '  + (JsStr $p.art) }
  if ($p.code) { $extra += ', code: ' + (JsStr $p.code) }
  if ($p.prev) { $extra += ', prev: ' + (JsStr $p.prev) }
  if ($p.big)  { $extra += ', big: '  + (JsStr $p.big) }
  $sp = JsSpecs $p.specs; if ($sp) { $extra += ', sp: ' + $sp }
  $av = JsAvail $p.avail; if ($av) { $extra += ', av: ' + $av }
  if ($p.tags -and $p.tags.Count) {
    $tj = foreach ($t in $p.tags) { '{ k: ' + (JsStr $t.kind) + ', t: ' + (JsStr $t.text) + ' }' }
    $extra += ', tg: [' + ($tj -join ',') + ']'
  }
  $vs = JsSpecs $p.vspecs; if ($vs) { $extra += ', vsp: ' + $vs }
  if ($p.vshots -and $p.vshots.Count) {
    $extra += ', vimg: [' + (($p.vshots | ForEach-Object { JsStr $_ }) -join ',') + ']'
  }
  if ($p.vurl) { $extra += ', vurl: ' + (JsStr $p.vurl) }

  $line = '  {{ id: {0}, n: {1}, b: {2}, p: {3}, pt: {4}, img: {5}, s: {6}, c: {7}, sc: {8}, u: {9}{10} }},' -f `
    (JsStr $p.id), (JsStr $p.name), (JsStr $p.brand), $p.price, (JsStr $p.priceText),
    (JsStr $p.img), $p.stock, (JsStr $p.cat), (JsStr $p.sub), (JsStr $p.url), $extra
  [void]$sb.AppendLine($line)
}
[void]$sb.AppendLine('];')
[void]$sb.AppendLine('')

# categories
[void]$sb.AppendLine('const CATEGORIES = [')
foreach ($c in $catsOut) {
  [void]$sb.AppendLine('  {')
  [void]$sb.AppendLine('    id: ' + (JsStr $c.id) + ', name: ' + (JsStr $c.name) + ', icon: ' + (JsStr $c.icon) + ',')
  [void]$sb.AppendLine('    ids: [' + (($c.ids | ForEach-Object { JsStr $_ }) -join ',') + '],')
  [void]$sb.AppendLine('    sub: [')
  foreach ($s in $c.sub) {
    [void]$sb.AppendLine('      { id: ' + (JsStr $s.id) + ', name: ' + (JsStr $s.name) + ', ids: [' + (($s.ids | ForEach-Object { JsStr $_ }) -join ',') + '] },')
  }
  [void]$sb.AppendLine('    ]')
  [void]$sb.AppendLine('  },')
}
[void]$sb.AppendLine('];')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('const PMAP = Object.fromEntries(PRODUCTS.map(p => [p.id, p]));')

$outPath = Join-Path $root 'assets\js\data.js'
[IO.File]::WriteAllText($outPath, $sb.ToString(), (New-Object Text.UTF8Encoding($true)))

$subCount = (($catsOut | ForEach-Object { $_.sub.Count }) | Measure-Object -Sum).Sum
$short = 0
foreach ($c in $catsOut) {
  if ($c.ids.Count -lt $MinPer) { $short++ }
  foreach ($s in $c.sub) { if ($s.ids.Count -lt $MinPer) { $short++ } }
}
Write-Host 'data.js written' -ForegroundColor Green
Write-Host ("  categories    : {0}" -f $catsOut.Count)
Write-Host ("  subcategories : {0}" -f $subCount)
Write-Host ("  products      : {0}" -f $order.Count)
Write-Host ("  nodes under {0} : {1}" -f $MinPer, $short)
