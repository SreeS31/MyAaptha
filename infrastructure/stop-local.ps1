$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$record = Join-Path $projectRoot '.tools/preview/processes.json'
if (Test-Path -LiteralPath $record) {
    foreach ($entry in (Get-Content -LiteralPath $record -Raw | ConvertFrom-Json)) {
        if (-not $entry.id -or -not $entry.startedAt) { throw 'Old process record; stop the original preview processes manually once.' }
        $process = Get-Process -Id $entry.id -ErrorAction SilentlyContinue
        if ($process -and $process.ProcessName -eq $entry.name -and
            $process.StartTime.ToUniversalTime().ToString('o') -eq $entry.startedAt) {
            Stop-Process -InputObject $process
        }
    }
    Remove-Item -LiteralPath $record
}
& docker compose -f (Join-Path $PSScriptRoot 'local-compose.yml') stop
if ($LASTEXITCODE -ne 0) { throw 'Could not stop preview dependencies.' }
Write-Output 'Local preview stopped. Its database volume is preserved.'
