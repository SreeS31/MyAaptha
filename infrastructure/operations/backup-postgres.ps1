param([Parameter(Mandatory=$true)][string]$OutputDirectory,[ValidateRange(1,36500)][int]$RetentionDays=30)
$ErrorActionPreference='Stop'
if ([string]::IsNullOrWhiteSpace($env:DATABASE_URL)) { throw 'Set DATABASE_URL explicitly before backup' }
$resolved=[System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $resolved | Out-Null
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss-fff') + '-' + [Guid]::NewGuid().ToString('N')
$file=Join-Path $resolved "myaaptha-$stamp.dump"
$partial="$file.partial"
try {
  & pg_dump --no-password --format=custom --no-owner "--file=$partial" $env:DATABASE_URL
  if($LASTEXITCODE -ne 0){throw 'PostgreSQL backup failed'}
  if (-not (Test-Path -LiteralPath $partial -PathType Leaf) -or (Get-Item -LiteralPath $partial).Length -eq 0) { throw 'Backup output is missing or empty' }
  Get-FileHash -LiteralPath $partial -Algorithm SHA256 | Select-Object Hash | ConvertTo-Json | Set-Content -LiteralPath "$partial.sha256.json" -Encoding UTF8
  Move-Item -LiteralPath "$partial.sha256.json" -Destination "$file.sha256.json"
  Move-Item -LiteralPath $partial -Destination $file
} catch {
  # Only the generated files from this attempt may be removed. Existing backups remain intact.
  foreach ($candidate in @($partial, "$partial.sha256.json", "$file.sha256.json")) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { Remove-Item -LiteralPath $candidate -Force }
  }
  throw
}
$cutoff=(Get-Date).ToUniversalTime().AddDays(-$RetentionDays)
foreach ($expired in (Get-ChildItem -LiteralPath $resolved -Filter 'myaaptha-*.dump' -File | Where-Object {$_.LastWriteTimeUtc -lt $cutoff -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)})) {
  # Retention is restricted to regular dump files directly inside the explicit output directory.
  if ($expired.Directory.FullName -ne $resolved.TrimEnd([IO.Path]::DirectorySeparatorChar)) { throw 'Unexpected backup retention path' }
  $sidecar="$($expired.FullName).sha256.json"
  Remove-Item -LiteralPath $expired.FullName -Force
  if (Test-Path -LiteralPath $sidecar -PathType Leaf) { Remove-Item -LiteralPath $sidecar -Force }
}
Write-Output $file
