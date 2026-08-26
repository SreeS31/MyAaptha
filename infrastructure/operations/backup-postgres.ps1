param([Parameter(Mandatory=$true)][string]$OutputDirectory,[int]$RetentionDays=30)
$ErrorActionPreference='Stop'
$resolved=[System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $resolved | Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$file=Join-Path $resolved "myaaptha-$stamp.dump"
& pg_dump --format=custom --no-owner --file=$file $env:DATABASE_URL
if($LASTEXITCODE -ne 0){throw 'PostgreSQL backup failed'}
Get-ChildItem -LiteralPath $resolved -Filter 'myaaptha-*.dump' | Where-Object {$_.LastWriteTimeUtc -lt (Get-Date).ToUniversalTime().AddDays(-$RetentionDays)} | Remove-Item -Force
Write-Output $file
