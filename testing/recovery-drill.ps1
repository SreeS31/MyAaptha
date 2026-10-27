# Local synthetic command-path verification. No production targets or external credentials accepted.
param()
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$drillId=[Guid]::NewGuid().ToString('N')
$global:myaapthaDrillContainer="myaaptha-recovery-$drillId"
$artifactDirectory=Join-Path $projectRoot ".tools/launch-board/recovery-$drillId"
New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
$created=$false
function Invoke-DrillDocker {
  & docker @args
  if ($LASTEXITCODE -ne 0) { throw 'Disposable recovery container command failed' }
}
# Adapt local file arguments to the disposable container's explicitly mounted artifact directory.
function global:pg_dump {
  $commandArguments=@($args | ForEach-Object {
    if ($_ -like '--file=*') { '--file=/backup/' + [IO.Path]::GetFileName($_.Substring(7)) } else { $_ }
  })
  & docker exec $global:myaapthaDrillContainer pg_dump @commandArguments
  $global:LASTEXITCODE=$LASTEXITCODE
}
function global:psql {
  & docker exec $global:myaapthaDrillContainer psql @args
  $global:LASTEXITCODE=$LASTEXITCODE
}
function global:pg_restore {
  $commandArguments=@($args)
  $commandArguments[$commandArguments.Count-1]='/backup/' + [IO.Path]::GetFileName($commandArguments[-1])
  & docker exec $global:myaapthaDrillContainer pg_restore @commandArguments
  $global:LASTEXITCODE=$LASTEXITCODE
}
try {
  # Use only a cached image, no published port and no network interface beyond loopback.
  Invoke-DrillDocker create --pull=never --name $global:myaapthaDrillContainer --network=none -e POSTGRES_PASSWORD=synthetic-drill-only --mount "type=bind,source=$artifactDirectory,target=/backup" postgres:17-alpine | Out-Null
  $created=$true
  Invoke-DrillDocker start $global:myaapthaDrillContainer | Out-Null
  $ready=$false
  for ($attempt=0; $attempt -lt 60; $attempt++) {
    & docker exec $global:myaapthaDrillContainer pg_isready -U postgres 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $ready=$true; break }
    Start-Sleep -Milliseconds 500
  }
  if (-not $ready) { throw 'Disposable PostgreSQL did not become ready' }
  foreach ($database in @('drill_source','drill_target')) {
    Invoke-DrillDocker exec $global:myaapthaDrillContainer createdb -U postgres $database
  }
  Invoke-DrillDocker exec $global:myaapthaDrillContainer psql -U postgres -d drill_source -v ON_ERROR_STOP=1 -c "CREATE TABLE recovery_fixture(id INTEGER PRIMARY KEY, value TEXT NOT NULL); INSERT INTO recovery_fixture VALUES (1,'synthetic-one'),(2,'synthetic-two');" | Out-Null
  $env:DATABASE_URL='postgresql://postgres:synthetic-drill-only@127.0.0.1/drill_source'
  $backup=& (Join-Path $projectRoot 'infrastructure/operations/backup-postgres.ps1') -OutputDirectory $artifactDirectory
  $target='postgresql://postgres:synthetic-drill-only@127.0.0.1/drill_target'
  & (Join-Path $projectRoot 'infrastructure/operations/restore-postgres.ps1') -BackupFile $backup -TargetDatabaseUrl $target
  $actual=Invoke-DrillDocker exec $global:myaapthaDrillContainer psql -U postgres -d drill_target -At -c 'SELECT id,value FROM recovery_fixture ORDER BY id'
  if (($actual -join '|') -ne '1|synthetic-one|2|synthetic-two') { throw 'Restored synthetic rows differ' }
  $rejected=$false
  try { & (Join-Path $projectRoot 'infrastructure/operations/restore-postgres.ps1') -BackupFile $backup -TargetDatabaseUrl $target }
  catch { if ($_.Exception.Message -notlike '*empty database*') { throw }; $rejected=$true }
  if (-not $rejected) { throw 'Nonempty target was not rejected' }
  [PSCustomObject]@{ syntheticRows=2; restoreMatched=$true; nonemptyTargetRejected=$true; releaseApproved=$false; productionRecoveryVerified=$false } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $artifactDirectory 'result.json') -Encoding UTF8
  Write-Output "PASS: synthetic backup/restore matched; second restore rejected; evidence: $artifactDirectory"
} finally {
  if ($created) { & docker rm -f -v $global:myaapthaDrillContainer 2>$null | Out-Null }
}
