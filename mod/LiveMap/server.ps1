# LiveMap local web server. Serves the web folder on http://localhost:<Port>/
# Exits automatically when the game process is gone.
param(
    [int]$Port = 8765,
    [string]$Root = (Join-Path $PSScriptRoot 'web'),
    [switch]$Open
)

$url = "http://localhost:$Port/"
$gameName = 'RSDragonwilds-Win64-Shipping'

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
try {
    $listener.Start()
} catch {
    # Port already taken: most likely a server from an earlier launch is still running.
    if ($Open) { Start-Process $url }
    exit
}
if ($Open) { Start-Process $url }

$mime = @{
    '.html' = 'text/html; charset=utf-8'; '.js' = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
    '.txt' = 'text/plain; charset=utf-8'; '.png' = 'image/png'; '.jpg' = 'image/jpeg'
    '.jpeg' = 'image/jpeg'; '.webp' = 'image/webp'; '.svg' = 'image/svg+xml'
}
$cache = @{}
$rootFull = [System.IO.Path]::GetFullPath($Root)
$lastGameSeen = Get-Date

while ($listener.IsListening) {
    $ar = $listener.BeginGetContext($null, $null)
    while (-not $ar.AsyncWaitHandle.WaitOne(2000)) {
        if (Get-Process -Name $gameName -ErrorAction SilentlyContinue) {
            $lastGameSeen = Get-Date
        } elseif (((Get-Date) - $lastGameSeen).TotalSeconds -gt 30) {
            $listener.Stop()
            exit
        }
    }
    try {
        $ctx = $listener.EndGetContext($ar)
    } catch { continue }
    $res = $ctx.Response
    try {
        $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
        if ($path -eq '/') { $path = '/index.html' }
        $file = [System.IO.Path]::GetFullPath((Join-Path $rootFull $path.TrimStart('/')))
        $bytes = $null
        if ($file.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
            # The game rewrites data files constantly; retry briefly and fall back to the last good copy.
            for ($i = 0; $i -lt 5 -and $null -eq $bytes; $i++) {
                try { $bytes = [System.IO.File]::ReadAllBytes($file); $cache[$file] = $bytes }
                catch { Start-Sleep -Milliseconds 15 }
            }
            if ($null -eq $bytes) { $bytes = $cache[$file] }
        }
        if ($null -eq $bytes) {
            $res.StatusCode = 404
            $bytes = [Text.Encoding]::UTF8.GetBytes('not found')
        } else {
            $ext = [System.IO.Path]::GetExtension($file).ToLower()
            $res.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
        }
        $res.AddHeader('Cache-Control', 'no-store')
        $res.ContentLength64 = $bytes.Length
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } catch {
    } finally {
        try { $res.Close() } catch {}
    }
}
