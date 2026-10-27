param([ValidateRange(1024,65535)][int]$Port = 4317)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$boardUrl = "http://127.0.0.1:$Port/docs/launch-board/index.html"
$listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
if ($listener) {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $boardUrl -TimeoutSec 3
    if ($response.Content -notmatch '<title>MyAaptha Launch Board</title>') { throw "Port $Port is occupied by another service." }
    Write-Output $boardUrl
    return
}
$logs = Join-Path $projectRoot '.tools/launch-board'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$python = (Get-Command python -ErrorAction Stop).Source
$serverScript = Join-Path $PSScriptRoot 'launch_board_server.py'
$process = Start-Process -FilePath $python -ArgumentList @("`"$serverScript`"", '--port', $Port) -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs 'server.log') -RedirectStandardError (Join-Path $logs 'server-error.log')
@{id=$process.Id;port=$Port;started=$process.StartTime.ToUniversalTime().ToString('o');url=$boardUrl} | ConvertTo-Json | Set-Content (Join-Path $logs 'server.json')
for ($attempt=0; $attempt -lt 30; $attempt++) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $boardUrl -TimeoutSec 1
        if ($response.StatusCode -eq 200) { Write-Output $boardUrl; return }
    } catch { Start-Sleep -Milliseconds 300 }
}
throw 'Launch-board server did not become ready. Inspect .tools/launch-board logs.'
