# Read-only release prerequisite check

20 October 2026. Related task: M15.4. This checks local configuration readiness, not cloud provisioning or release approval.

```powershell
python infrastructure/preflight_release.py infrastructure/release.json
```

For Compose-mounted inputs outside the default production directory:

```powershell
python infrastructure/preflight_release.py infrastructure/release.json --production C:/protected/myaaptha-production --field-active-key-id primary
```

The release JSON uses the existing renderer contract, including immutable image digests, real endpoint names, trusted proxy expression and rollout connection budget. The production directory supplies `secrets/postgres_password`, `secrets/redis_password`, `secrets/jwt_secret`, `secrets/field_encryption_keys`, `secrets/admin_mfa_encryption_key` and `certs/postgres-ca.crt`. Match the active key option to the actual deployment environment. Field keys are comma-separated `id=Base64` entries containing 32-byte keys; the administrator MFA key is a separate Base64-encoded 32-byte key. Keep all credentials in protected local configuration or secret-manager workflows, never chat or source control.

Exit zero means these local inputs passed format checks. Exit one means a missing, unreadable or invalid prerequisite. The JSON contains only named checks, status and generic remediation, with no credential values, file content or raw exception messages. Checks reject oversized inputs, malformed/placeholder release configuration, weak/placeholder credentials, duplicate field key IDs, missing active keys and unparsable/non-CA trust bundles. Direct symlink/junction file inputs are rejected. The program makes no HTTP, Docker or cloud calls and writes no files; shell redirection can save its sanitized report.

This is a combined local Kubernetes-renderer JSON/Compose-mounted-input check, not a complete platform validator. Secret-manager-only Kubernetes deployments must validate the actual injected secret mappings separately. Passing does not prove credential entropy, provider identity, CA expiry/hostname validation, remote connectivity, IAM, bucket privacy, scanner readiness, budget approval, provider delivery or any live acceptance. `releaseApproved` and `externalServicesContacted` always remain false.

## Current result

The selected `infrastructure/release.json` and six protected secret/CA inputs are not provisioned in the default production layout. All seven checks reported false. This explains a concrete staging dependency; it is not a request for permission to code. No development/local-preview credentials were copied into production.

Five new unit tests passed, covering missing inputs, credential/key formats, output redaction, malformed/oversized configuration, active-key selection and refusal to turn local checks into live approval. The successful certificate-path unit fixture is mocked; malformed CA rejection uses the real SSL parser. See the [current development report](DEVELOPMENT-2026-10-20.md) and [owner dependency map](OWNER-INPUTS-2026-10-20.md).
