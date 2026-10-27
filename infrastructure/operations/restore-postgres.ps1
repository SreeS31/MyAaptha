param([Parameter(Mandatory=$true)][string]$BackupFile,[Parameter(Mandatory=$true)][string]$TargetDatabaseUrl)
$ErrorActionPreference='Stop'
if ([string]::IsNullOrWhiteSpace($TargetDatabaseUrl)) { throw 'Set an explicit target database URL' }
$resolved=[System.IO.Path]::GetFullPath($BackupFile)
if(-not (Test-Path -LiteralPath $resolved -PathType Leaf)){throw 'Backup file not found'}
# Restore only into a newly provisioned empty database. Never drop production objects.
$checksumFile = "$resolved.sha256.json"
if (-not (Test-Path -LiteralPath $checksumFile -PathType Leaf)) { throw 'Backup checksum file is required' }
$expected = (Get-Content -LiteralPath $checksumFile -Raw | ConvertFrom-Json).Hash
if ($expected -isnot [string] -or $expected -notmatch '^[a-fA-F0-9]{64}$') { throw 'Backup checksum is malformed' }
if ((Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash -ne $expected) { throw 'Backup checksum does not match' }
# Fail closed if the target has user-owned objects or cannot be inspected. This check is not a
# lock: keep the target isolated from applications and other writers throughout the drill.
$query = "SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname NOT IN ('pg_catalog','information_schema') AND n.nspname NOT LIKE 'pg_toast%' AND c.relkind IN ('r','p','v','m','S','f')"
$objects = & psql --no-password --no-psqlrc --tuples-only --no-align --set=ON_ERROR_STOP=1 "--dbname=$TargetDatabaseUrl" "--command=$query"
if ($LASTEXITCODE -ne 0 -or ($objects -join '').Trim() -ne '0') { throw 'Restore requires an accessible empty database with no user relations' }
& pg_restore --no-password --exit-on-error --single-transaction --no-owner --dbname=$TargetDatabaseUrl $resolved
if($LASTEXITCODE -ne 0){throw 'PostgreSQL restore failed'}
