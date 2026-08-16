<#
  Уменьшает фотографии товаров до разумного размера для репозитория.
  Файлы перезаписываются на месте; исходники всегда можно перекачать
  скриптами extract-details.ps1 / extract-catalog.ps1.
#>

param(
  [int]$MaxSide = 1200,
  [int]$Quality = 85,
  [string[]]$Dirs = @('assets\img\products-lg', 'assets\img\vendor', 'assets\img\hero')
)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)

$before = 0; $after = 0; $touched = 0; $total = 0

foreach ($dir in $Dirs) {
  $full = Join-Path $root $dir
  if (-not (Test-Path $full)) { continue }
  foreach ($f in Get-ChildItem $full -File) {
    $total++
    $before += $f.Length
    try {
      $img = [System.Drawing.Bitmap]::FromFile($f.FullName)
      $w = $img.Width; $h = $img.Height
      $maxSideNow = [Math]::Max($w, $h)
      if ($maxSideNow -le $MaxSide) { $img.Dispose(); $after += $f.Length; continue }

      $scale = $MaxSide / $maxSideNow
      $nw = [int][Math]::Round($w * $scale); $nh = [int][Math]::Round($h * $scale)

      $isPng = $f.Extension -match '(?i)\.png'
      $fmt = if ($isPng) { [System.Drawing.Imaging.PixelFormat]::Format32bppArgb } else { [System.Drawing.Imaging.PixelFormat]::Format24bppRgb }
      $dst = New-Object System.Drawing.Bitmap($nw, $nh, $fmt)
      $g = [System.Drawing.Graphics]::FromImage($dst)
      $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
      $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      if (-not $isPng) { $g.Clear([System.Drawing.Color]::White) }
      $g.DrawImage($img, 0, 0, $nw, $nh)
      $g.Dispose(); $img.Dispose()

      $tmp = $f.FullName + '.tmp'
      if ($isPng) { $dst.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png) }
      else        { $dst.Save($tmp, $jpegCodec, $encParams) }
      $dst.Dispose()

      Move-Item $tmp $f.FullName -Force
      $touched++
      $after += (Get-Item $f.FullName).Length
    } catch {
      Write-Host ("не удалось: {0} — {1}" -f $f.Name, $_.Exception.Message) -ForegroundColor DarkYellow
      $after += $f.Length
    }
  }
}

Write-Host ''
Write-Host 'Готово.' -ForegroundColor Green
Write-Host ("  файлов просмотрено: {0}, уменьшено: {1}" -f $total, $touched)
Write-Host ("  было:  {0} МБ" -f [math]::Round($before / 1mb, 1))
Write-Host ("  стало: {0} МБ" -f [math]::Round($after / 1mb, 1))
