$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $projectRoot '.tools/preview/openai-key.dpapi'
New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
$secret = Read-Host 'Enter your OpenAI API key (input is hidden)' -AsSecureString
if ($secret.Length -lt 20) { throw 'No valid key was entered. Existing configuration was preserved.' }
$secret | ConvertFrom-SecureString | Set-Content -LiteralPath $destination
$secret.Dispose()
Write-Output 'Key saved encrypted for this Windows user. Restart the local preview to enable OpenAI answers.'
