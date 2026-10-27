param([switch]$SkipBuild, [string]$Database, [ValidateRange(1024,65535)][int]$RedisPort = 16379)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$logs = Join-Path $projectRoot '.tools/preview'
New-Item -ItemType Directory -Force -Path $logs | Out-Null

function Assert-Success($step) {
    if ($LASTEXITCODE -ne 0) { throw "$step failed ($LASTEXITCODE)" }
}
function Wait-Healthy($url) {
    for ($attempt = 0; $attempt -lt 120; $attempt++) {
        try { Invoke-WebRequest -UseBasicParsing $url -TimeoutSec 2 | Out-Null; return } catch { Start-Sleep -Seconds 1 }
    }
    throw "Service did not become ready: $url. Inspect $logs."
}
foreach ($port in @(3000,8080,8081)) {
    if (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) {
        throw "Port $port is already in use. The preview may already be running."
    }
}
if (-not $SkipBuild) {
    $mavenCommand = Get-Command mvn.cmd -ErrorAction SilentlyContinue
    $mavenPath = if ($mavenCommand) { $mavenCommand.Source } else { 'C:/opt/maven/apache-maven-3.9.9/bin/mvn.cmd' }
    if (-not (Test-Path $mavenPath)) { throw 'Install Maven and add mvn.cmd to PATH.' }
    Push-Location (Join-Path $projectRoot 'backend/spring-boot-app')
    try { & $mavenPath --batch-mode verify; Assert-Success 'API build' } finally { Pop-Location }
    Push-Location (Join-Path $projectRoot 'frontend/nextjs-app')
    try { & npm.cmd run build; Assert-Success 'Web build' } finally { Pop-Location }
}
# Avoid Windows' dynamic/Hyper-V reserved port ranges; allow an explicit override.
$env:MYAAPTHA_PREVIEW_REDIS_PORT = "$RedisPort"
& docker compose -f (Join-Path $PSScriptRoot 'local-compose.yml') up -d --wait
Assert-Success 'Local dependencies'
$env:SPRING_DATA_REDIS_HOST = '127.0.0.1'
$env:SPRING_DATA_REDIS_PORT = "$RedisPort"
$env:SPRING_DATA_REDIS_PASSWORD = 'myaaptha-local-preview-only'
# Local preview only. Production uses the separate validated TLS/secret configuration.
$env:CLAMAV_HOST='127.0.0.1'
$env:CLAMAV_PORT='53310'
$env:MYAAPTHA_MEDIA_SCANNER='clamav'
& python (Join-Path $PSScriptRoot 'check_scanner.py') --host $env:CLAMAV_HOST --port $env:CLAMAV_PORT --reload-if-stale --wait 60
Assert-Success 'Antivirus signature freshness'
$env:DEBUG='false'
$env:TRACE='false'
$env:POSTGRES_HOST='127.0.0.1'
$env:POSTGRES_PORT='55432'
$databaseSetting = Join-Path $logs 'database.txt'
if (-not $Database) {
    $Database = if (Test-Path $databaseSetting) { (Get-Content $databaseSetting -Raw).Trim() } else { 'myaaptha' }
}
if ($Database -notmatch '^[a-z][a-z0-9_]*$') { throw 'Invalid local database name.' }
$env:POSTGRES_DB=$Database
$env:POSTGRES_USER='myaaptha'
$env:POSTGRES_PASSWORD='myaaptha-local-preview-only'
if (-not $env:OPENAI_API_KEY) { $env:OPENAI_API_KEY = [Environment]::GetEnvironmentVariable('OPENAI_API_KEY','User') }
$keyFile = Join-Path $logs 'openai-key.dpapi'
if (-not $env:OPENAI_API_KEY -and (Test-Path -LiteralPath $keyFile)) {
    $protectedKey = (Get-Content -LiteralPath $keyFile -Raw).Trim() | ConvertTo-SecureString
    $env:OPENAI_API_KEY = [System.Net.NetworkCredential]::new('', $protectedKey).Password
    $protectedKey.Dispose()
}
if (-not $env:OPENAI_API_KEY) { Write-Warning 'OpenAI is not configured. Run infrastructure/configure-openai-local.ps1 locally, then restart the preview.' }
$env:MYAAPTHA_BASE_URL='http://127.0.0.1:8081/api/v1'
$contactKeyFile=Join-Path $logs 'contact-providers.dpapi'
if(Test-Path -LiteralPath $contactKeyFile){
    $protectedContacts=(Get-Content -LiteralPath $contactKeyFile -Raw).Trim() | ConvertTo-SecureString
    $contactSettings=[System.Net.NetworkCredential]::new('', $protectedContacts).Password | ConvertFrom-Json
    if(-not $env:GOOGLE_CONTACTS_CLIENT_ID){$env:GOOGLE_CONTACTS_CLIENT_ID=$contactSettings.googleId}
    if(-not $env:GOOGLE_CONTACTS_CLIENT_SECRET){$env:GOOGLE_CONTACTS_CLIENT_SECRET=$contactSettings.googleSecret}
    if(-not $env:MICROSOFT_CONTACTS_CLIENT_ID){$env:MICROSOFT_CONTACTS_CLIENT_ID=$contactSettings.microsoftId}
    if(-not $env:MICROSOFT_CONTACTS_CLIENT_SECRET){$env:MICROSOFT_CONTACTS_CLIENT_SECRET=$contactSettings.microsoftSecret}
    $protectedContacts.Dispose()
    $contactSettings=$null
}
$env:MYAAPTHA_WEB_ORIGIN='http://localhost:3000'
$env:MYAAPTHA_CORS_ALLOWED_ORIGINS='http://localhost:3000,http://127.0.0.1:3000'
$env:SECURITY_WEB_COOKIE_SECURE='false'
$env:SPRING_PROFILES_ACTIVE='local'
$env:SERVER_ADDRESS='127.0.0.1'
$env:PYTHONPATH=Join-Path $projectRoot 'ai/agent-service/src'
$script:previewProcesses = @()
function Save-PreviewProcess($process) {
    $script:previewProcesses += @{id=$process.Id;name=$process.ProcessName;startedAt=$process.StartTime.ToUniversalTime().ToString('o')}
    ConvertTo-Json -InputObject $script:previewProcesses | Set-Content (Join-Path $logs 'processes.json')
}
$ai = Start-Process python -ArgumentList '-m uvicorn ai_service.main:app --host 127.0.0.1 --port 8081' -WorkingDirectory (Join-Path $projectRoot 'ai/agent-service') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs 'ai.log') -RedirectStandardError (Join-Path $logs 'ai-error.log')
Save-PreviewProcess $ai
Wait-Healthy 'http://127.0.0.1:8081/api/v1/ready'
$api = Start-Process java -ArgumentList '-Xmx512m -jar target/myaaptha-service-0.1.0.jar' -WorkingDirectory (Join-Path $projectRoot 'backend/spring-boot-app') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs 'api.log') -RedirectStandardError (Join-Path $logs 'api-error.log')
Save-PreviewProcess $api
Wait-Healthy 'http://127.0.0.1:8080/api/auth/health'
$webRoot = Join-Path $projectRoot 'frontend/nextjs-app'
foreach ($asset in @('public','.next/static')) {
    $destination = Join-Path (Join-Path $webRoot '.next/standalone') $asset
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $webRoot $asset) | Copy-Item -Destination $destination -Recurse -Force
}
$env:PORT='3000'
$env:HOSTNAME='127.0.0.1'
$web = Start-Process node -ArgumentList '.next/standalone/server.js' -WorkingDirectory $webRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs 'web.log') -RedirectStandardError (Join-Path $logs 'web-error.log')
Save-PreviewProcess $web
Wait-Healthy 'http://127.0.0.1:3000'
@($ai,$api,$web) | ForEach-Object {
    @{id=$_.Id;name=$_.ProcessName;startedAt=$_.StartTime.ToUniversalTime().ToString('o')}
} | ConvertTo-Json | Set-Content (Join-Path $logs 'processes.json')
Write-Output 'MyAaptha is ready at http://localhost:3000'
