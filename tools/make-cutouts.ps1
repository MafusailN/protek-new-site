<#
  Готовит вырезки товаров для фоновых подложек: убирает белый фон,
  обрезает поля и уменьшает размер.

  Результат: assets\img\hero\<имя>.png
#>

param(
  [string[]]$Ids,
  [int]$Threshold = 242,   # пиксели светлее — считаем фоном
  [int]$MaxSide   = 900
)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Continue'

$root = Split-Path -Parent $PSScriptRoot
$dstDir = Join-Path $root 'assets\img\hero'
New-Item -ItemType Directory -Force -Path $dstDir | Out-Null

$srcDirs = @((Join-Path $root 'assets\img\products-lg'), (Join-Path $root 'assets\img\products'))

# при запуске через -File список приходит одной строкой «1,2,3»
$Ids = $Ids | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }

foreach ($id in $Ids) {
  $srcFile = $null
  foreach ($dir in $srcDirs) {
    $f = Get-ChildItem $dir -File -Filter "$id.*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($f) { $srcFile = $f; break }
  }
  if (-not $srcFile) { Write-Host "$id — файл не найден" -ForegroundColor DarkYellow; continue }

  try {
    $img = [System.Drawing.Bitmap]::FromFile($srcFile.FullName)
    $w = $img.Width; $h = $img.Height
    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.DrawImage($img, 0, 0, $w, $h)
    $g.Dispose(); $img.Dispose()

    # Прозрачным делаем только фон — заливкой от краёв. Простой порог
    # «любой белый убрать» выедал белые части самого товара.
    $isLight = New-Object 'bool[]' ($w * $h)
    for ($y = 0; $y -lt $h; $y++) {
      for ($x = 0; $x -lt $w; $x++) {
        $c = $bmp.GetPixel($x, $y)
        if ($c.R -ge $Threshold -and $c.G -ge $Threshold -and $c.B -ge $Threshold) { $isLight[$y * $w + $x] = $true }
      }
    }

    $bg = New-Object 'bool[]' ($w * $h)
    $q = New-Object System.Collections.Generic.Queue[int]
    $lastRow = ($h - 1) * $w
    for ($x = 0; $x -lt $w; $x++) {
      $i = $x
      if ($isLight[$i] -and -not $bg[$i]) { $bg[$i] = $true; $q.Enqueue($i) }
      $i = $lastRow + $x
      if ($isLight[$i] -and -not $bg[$i]) { $bg[$i] = $true; $q.Enqueue($i) }
    }
    for ($y = 0; $y -lt $h; $y++) {
      $i = $y * $w
      if ($isLight[$i] -and -not $bg[$i]) { $bg[$i] = $true; $q.Enqueue($i) }
      $i = $y * $w + ($w - 1)
      if ($isLight[$i] -and -not $bg[$i]) { $bg[$i] = $true; $q.Enqueue($i) }
    }
    while ($q.Count -gt 0) {
      $i = $q.Dequeue()
      $cx = $i % $w
      $cy = ($i - $cx) / $w

      if ($cx -gt 0)      { $j = $i - 1;  if ($isLight[$j] -and -not $bg[$j]) { $bg[$j] = $true; $q.Enqueue($j) } }
      if ($cx -lt $w - 1) { $j = $i + 1;  if ($isLight[$j] -and -not $bg[$j]) { $bg[$j] = $true; $q.Enqueue($j) } }
      if ($cy -gt 0)      { $j = $i - $w; if ($isLight[$j] -and -not $bg[$j]) { $bg[$j] = $true; $q.Enqueue($j) } }
      if ($cy -lt $h - 1) { $j = $i + $w; if ($isLight[$j] -and -not $bg[$j]) { $bg[$j] = $true; $q.Enqueue($j) } }
    }

    $minX = $w; $minY = $h; $maxX = 0; $maxY = 0
    for ($y = 0; $y -lt $h; $y++) {
      for ($x = 0; $x -lt $w; $x++) {
        $i = $y * $w + $x
        if ($bg[$i]) {
          $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 255, 255, 255))
        } else {
          if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
          if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
        }
      }
    }
    if ($maxX -le $minX -or $maxY -le $minY) { $bmp.Dispose(); Write-Host "$id — предмет не найден" -ForegroundColor DarkYellow; continue }

    $pad = 4
    $minX = [Math]::Max(0, $minX - $pad); $minY = [Math]::Max(0, $minY - $pad)
    $maxX = [Math]::Min($w - 1, $maxX + $pad); $maxY = [Math]::Min($h - 1, $maxY + $pad)
    $cw = $maxX - $minX + 1; $ch = $maxY - $minY + 1

    $crop = $bmp.Clone((New-Object System.Drawing.Rectangle($minX, $minY, $cw, $ch)), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bmp.Dispose()

    $scale = [Math]::Min(1.0, $MaxSide / [Math]::Max($cw, $ch))
    $nw = [int]($cw * $scale); $nh = [int]($ch * $scale)
    $out = New-Object System.Drawing.Bitmap($nw, $nh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g2 = [System.Drawing.Graphics]::FromImage($out)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.DrawImage($crop, 0, 0, $nw, $nh)
    $g2.Dispose(); $crop.Dispose()

    $dst = Join-Path $dstDir "$id.png"
    $out.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
    Write-Host ("{0} -> {1}x{2}, {3} КБ" -f $id, $nw, $nh, [math]::Round((Get-Item $dst).Length / 1kb))
  } catch {
    Write-Host "$id — ошибка: $($_.Exception.Message)" -ForegroundColor Red
  }
}
