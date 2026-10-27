param(
  [Parameter(Mandatory=$true)][string]$Context,
  [Parameter(Mandatory=$true)][string]$ReleaseConfig,
  [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$VerifiedBackupReference
)
$ErrorActionPreference = 'Stop'
function Invoke-Kube {
  & kubectl --context $Context @args
  if ($LASTEXITCODE -ne 0) { throw 'Kubernetes operation failed; deployment stopped.' }
}
$rendered = Join-Path $PSScriptRoot 'kubernetes/rendered'
& python (Join-Path $PSScriptRoot 'render_release.py') $ReleaseConfig --output $rendered
if ($LASTEXITCODE -ne 0) { throw 'Release configuration failed validation.' }
Invoke-Kube apply -f (Join-Path $rendered 'namespace.yaml')
Invoke-Kube -n myaaptha get secret myaaptha-secrets -o name
Invoke-Kube -n myaaptha get secret myaaptha-tls -o name
Invoke-Kube -n myaaptha get configmap myaaptha-postgres-ca -o name
Invoke-Kube apply -f (Join-Path $rendered 'config.yaml')
Invoke-Kube apply -f (Join-Path $rendered 'network-policy.yaml')
# V56 changes numeric/private columns to ciphertext. Old writers must be stopped.
# The supplied reference identifies the backup whose restore was verified by the operator.
Write-Output "Entering maintenance; verified backup reference: $VerifiedBackupReference"
Invoke-Kube -n myaaptha delete hpa backend --ignore-not-found
$backend = & kubectl --context $Context -n myaaptha get deployment backend --ignore-not-found -o name
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect existing backend.' }
if ($backend) {
  Invoke-Kube -n myaaptha scale deployment/backend --replicas=0
  Invoke-Kube -n myaaptha wait --for=delete pod -l app=backend --timeout=300s
}
# A previous successful job is removed only so the next release can rerun it.
$job = & kubectl --context $Context -n myaaptha get job myaaptha-migrate --ignore-not-found -o json
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect migration job.' }
if ($job) {
  $state = $job | ConvertFrom-Json
  if ($state.status.active -gt 0) { throw 'A migration is already running.' }
  Invoke-Kube -n myaaptha delete job myaaptha-migrate --wait=true
}
Invoke-Kube apply -f (Join-Path $rendered 'migration-job.yaml')
Invoke-Kube -n myaaptha wait --for=condition=complete job/myaaptha-migrate --timeout=600s
$encryptionJob = & kubectl --context $Context -n myaaptha get job myaaptha-encrypt-fields --ignore-not-found -o json
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect encryption job.' }
if ($encryptionJob) {
  $state = $encryptionJob | ConvertFrom-Json
  if ($state.status.active -gt 0) { throw 'An encryption migration is already running.' }
  Invoke-Kube -n myaaptha delete job myaaptha-encrypt-fields --wait=true
}
Invoke-Kube apply -f (Join-Path $rendered 'encrypt-fields-job.yaml')
Invoke-Kube -n myaaptha wait --for=condition=complete job/myaaptha-encrypt-fields --timeout=3600s
# Any failure above leaves the backend stopped; never restart old writers on ciphertext.
Invoke-Kube apply -f (Join-Path $rendered 'app.yaml')
foreach ($app in @('backend','frontend','ai-agent')) {
  Invoke-Kube -n myaaptha rollout status "deployment/$app" --timeout=300s
}
Invoke-Kube apply -f (Join-Path $rendered 'ingress.yaml')
Write-Output 'Rollout completed. Run authenticated staging smoke tests before opening access.'
