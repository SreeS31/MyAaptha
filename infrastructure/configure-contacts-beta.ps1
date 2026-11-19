param(
    [Parameter(Mandatory=$true)][string]$CredentialsFile,
    [ValidateSet('google','microsoft')][string]$Provider='google'
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$credentialPath=(Resolve-Path -LiteralPath $CredentialsFile).Path
if ((Get-Item -LiteralPath $credentialPath).Length -gt 16384) { throw 'Expected an OAuth application JSON file.' }
$cloudCli=Join-Path $projectRoot '.tools/gcloud-portable/google-cloud-sdk/bin/gcloud.cmd'
$env:CLOUDSDK_PYTHON='C:/Program Files/Python312/python.exe'
$env:CLOUDSDK_CONFIG='C:/Users/vighn/AppData/Roaming/gcloud'
$remoteDirectory='/tmp/myaaptha-contact-setup-'+[Guid]::NewGuid().ToString('N')
$cloudArgs=@('--zone=asia-south1-a','--project=project-5c36c021-87c7-4cfc-833','--tunnel-through-iap','--quiet')
& $cloudCli compute ssh myaaptha-beta @cloudArgs "--command=install -d -m 700 $remoteDirectory"
if ($LASTEXITCODE -ne 0) { throw 'Could not create the protected setup directory.' }
& $cloudCli compute scp $credentialPath "myaaptha-beta:$remoteDirectory/credentials.json" @cloudArgs
if ($LASTEXITCODE -ne 0) { throw 'Could not transfer the owner-supplied credentials.' }
& $cloudCli compute scp (Join-Path $PSScriptRoot 'configure_beta_contact_oauth.py') myaaptha-beta:/tmp/configure_beta_contact_oauth.py @cloudArgs
if ($LASTEXITCODE -ne 0) { throw 'Could not transfer the activation helper.' }
& $cloudCli compute ssh myaaptha-beta @cloudArgs "--command=sudo python3 /tmp/configure_beta_contact_oauth.py --provider $Provider --credentials-file $remoteDirectory/credentials.json"
if ($LASTEXITCODE -ne 0) { throw 'Provider activation did not complete. No credential values have been printed.' }
