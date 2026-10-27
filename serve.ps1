param(
    [int]$Port = 8000,
    [string]$Path = (Join-Path $PSScriptRoot "map"),
    [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Path)) {
    Write-Error "Directory not found: $Path"
    exit 1
}

$FullPath = [System.IO.Path]::GetFullPath($Path)
$listener = New-Object System.Net.HttpListener
$url = "http://localhost:$Port/"
$listener.Prefixes.Add($url)

try {
    $listener.Start()
} catch {
    Write-Warning "Port $Port may be in use, trying port 8081..."
    $Port = 8081
    $url = "http://localhost:$Port/"
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($url)
    $listener.Start()
}

Write-Host "=========================================" -ForegroundColor Green
Write-Host "  UFO Goi Tra Bai - Web Server Dang Chay" -ForegroundColor Cyan
Write-Host "  Dia chi: $url" -ForegroundColor Yellow
Write-Host "  Thu muc: $FullPath" -ForegroundColor Gray
Write-Host "  Nhan Ctrl+C de dung server" -ForegroundColor Magenta
Write-Host "=========================================" -ForegroundColor Green

if (-not $NoBrowser) {
    Start-Process "$url"
}

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".mjs"  = "application/javascript; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".mp3"  = "audio/mpeg"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
    ".txt"  = "text/plain; charset=utf-8"
    ".wasm" = "application/wasm"
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $rawUrl = $request.Url.AbsolutePath
        $localPath = [Uri]::UnescapeDataString($rawUrl).TrimStart('/')

        if ([string]::IsNullOrWhiteSpace($localPath) -or $localPath -eq "index.html") {
            $localPath = "tui-mu.html"
        }

        $filePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($FullPath, $localPath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)))

        # Security check: must reside inside root
        if (-not $filePath.StartsWith($FullPath, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path $filePath -PathType Leaf)) {
            $response.StatusCode = 404
            $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $rawUrl")
            $response.ContentType = "text/plain; charset=utf-8"
            $response.ContentLength64 = $msg.Length
            $response.OutputStream.Write($msg, 0, $msg.Length)
            $response.Close()
            continue
        }

        $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
        $contentType = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { "application/octet-stream" }

        try {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $response.StatusCode = 200
            $response.ContentType = $contentType
            $response.ContentLength64 = $bytes.Length
            $response.AddHeader("Access-Control-Allow-Origin", "*")
            $response.AddHeader("Cache-Control", "no-cache")
            if ($request.HttpMethod -ne "HEAD") {
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
        } catch {
            $response.StatusCode = 500
        } finally {
            $response.Close()
        }
    }
} finally {
    $listener.Stop()
    $listener.Close()
}

