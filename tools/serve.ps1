<#
  Локальный просмотр сайта: http://localhost:8765/
  Запуск:  powershell -ExecutionPolicy Bypass -File .\serve.ps1
  Остановка: Ctrl+C
#>
param([int]$Port = 8765)

$root = Split-Path -Parent $PSScriptRoot
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Сайт: http://localhost:$Port/  (Ctrl+C — остановить)" -ForegroundColor Green

$mime = @{
  '.html'='text/html; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.js'='application/javascript; charset=utf-8'
  '.json'='application/json; charset=utf-8'; '.png'='image/png'; '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'
  '.gif'='image/gif'; '.svg'='image/svg+xml'; '.webp'='image/webp'; '.ico'='image/x-icon'
}

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    if (-not $rel) { $rel = 'index.html' }
    $path = Join-Path $root $rel
    if (Test-Path $path -PathType Leaf) {
      $bytes = [IO.File]::ReadAllBytes($path)
      $ext = [IO.Path]::GetExtension($path).ToLower()
      $ctx.Response.ContentType = $(if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' })
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $ctx.Response.StatusCode = 404
      $msg = [Text.Encoding]::UTF8.GetBytes('404')
      $ctx.Response.OutputStream.Write($msg, 0, $msg.Length)
    }
    $ctx.Response.OutputStream.Close()
  }
} finally { $listener.Stop() }
