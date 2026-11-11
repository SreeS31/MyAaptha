# GIGW 3.0 security feature check — 10 November 2026

Result: **partial technical alignment; production acceptance and certification pending**. This is a source/configuration review supported by the local test evidence in [the security review](security-gigw-review-2026-11-10.md), not an independent penetration test. Subsequent GCS, container and cloud changes and their validation are recorded in the [11 November deployment update](GCP-BETA-DEPLOYMENT-2026-11-11.md). GIGW is used as the requested benchmark for this private application.

Reference: [official GIGW cybersecurity guidelines](https://guidelines.india.gov.in/security-guidelines-and-attributes/). Its security framework covers application protection, hosting and approved policies; eligible independent audit clearance remains a separate production requirement. Do not describe these local checks as GIGW certification.

## Feature evidence

“Implemented” means inspected in source; “locally verified” means exercised by the recorded tests. Neither establishes the deployed cloud configuration.

| Control | Finding | Evidence and remaining scope |
| --- | --- | --- |
| Password storage | Implemented | `SecurityConfig` uses BCrypt; `AuthService` matches hashes. Passwords are not reversibly encrypted. |
| Refresh sessions | Locally verified | Database stores SHA-256 token fingerprints; refresh rotates sessions; login/refresh/recovery tests pass. Multiple-device sessions are intentional application behavior and need documented policy. |
| Administrator MFA | Implemented, production enforced | `AdminMfaService` verifies TOTP, encrypts its secrets with AES-GCM and rejects reused counters. Production guard requires MFA; real enrollment and device acceptance remain open. |
| Cookie protection | Implemented | Browser access/refresh cookies use `__Host-`, Secure, HttpOnly, SameSite Strict and root path. Session responses use no-store. Live HTTPS/proxy validation remains open. |
| Browser mutation protection | Implemented | Cookie-authenticated mutations require an allowed Origin and custom header. Spring's default CSRF filter is replaced by this control. Native bearer clients follow a separate path. |
| CORS | Implemented | Explicit configured origins with credentials; production rejects HTTP/placeholder public origins. Actual deployed allowlist remains open. |
| Authorization | Locally verified | Member/admin separation, forged JWT rejection, cross-user circles and financial-record isolation pass; this does not exhaust every API/object combination. |
| Encryption | Locally verified | Field encryption rejects tampering/wrong keys and supports rotation. Real PostgreSQL stores financial ciphertext. Secret-manager/IAM/key-rotation operation remains open. |
| Upload validation | Locally verified | Type/content/size validation and synthetic malware rejection tests pass. Production requires ClamAV; scanner enforces fresh signatures and rejects uploads when scanning fails. Actual deployed signature updates remain open. |
| Request abuse | Implemented; runtime dependency failure checked | Rate limits and upload budgets use shared Redis; raw untrusted forwarded-header mode is refused. Redis outage fails protected requests closed. Real edge limits and distributed-load acceptance remain open. |
| XSS/clickjacking | Locally verified for tested pages | Nonce-based CSP, strict-dynamic, no production unsafe-eval, frame restrictions and content-type headers. Injected parser script is blocked in the production browser test. All sinks/pages still require review. |
| Error handling | Locally verified | Error responses redact exception details; upload/security tests check incident recording and member denial on admin reports. Log storage/access/retention remain open. |
| Transport | Partially verified | Production PostgreSQL verify-full and Redis TLS passed local smoke. Public certificates, obsolete TLS/cipher rejection, redirects and internal application-hop encryption require live verification. Compose currently uses HTTP between some application services. |
| Server banner | Corrected locally | Added `-Server` to the production Caddy header block and `--no-server-header` to the AI image command. Cached Caddy 2.10 config validation passed offline; installed Uvicorn supports the flag. Rebuilt runtime images/live header readback remain required. |
| Container isolation | Templates inspected | Non-root app images, read-only application filesystems, dropped capabilities and no-new-privileges are present. Actual image scans and deployment readback remain open. |
| Network isolation | Partial templates | Kubernetes denies unsolicited inbound traffic. Existing policies do not restrict outbound internet access. Private dependencies, egress controls and GCP WAF are not verified. |
| Recovery | Locally verified | Disposable TLS database/cache outage recovery and encrypted object version restore passed. Cloud backup schedules/PITR/DR, restore objectives and elapsed expiry remain open. |
| Accessibility | Limited automated verification | Landing-page WCAG 2.1 A/AA axe checks detect no violations on desktop/mobile. Authenticated screens, documents and manual assistive-technology assessment remain open. |
| Policies | Gap | `/privacy` is an authenticated blocked-account screen. Approved public privacy/security/terms/copyright policies and contingency/incident plans are not demonstrated. Do not invent statements about actual operations. |
| Logging and ownership | Gap | Security incidents are recorded, but 180-day cloud log retention, India log placement, alert delivery, responsible contacts and incident-response acceptance are not demonstrated. |
| Independent clearance | Gap | No eligible independent audit certificate was supplied or verified. |

## Reused verification results

- Maven verify: 258 run, zero failures/errors, three skipped; the S3 opt-in test subsequently passed separately. Two Redis-specific test classes remain skipped in the default run.
- Production web build passed. All 14 browser cases passed; the Windows runner required interruption during teardown.
- Frontend units: 23 passed. AI: 11 passed, rerun successfully after the image-command edit. Infrastructure: 91 passed. Flutter: 102 passed, two skipped.
- Production npm audit: zero reported known vulnerabilities. Other ecosystems and final container images do not have fresh complete clean vulnerability evidence.
- Offline tracked-source secret scan was repeated with the current hardening changes and an explicit Docker exit code: exit 0, zero secret findings. Retained report: `.tools/trivy-cache/security-secrets-verified-20261110.json`; log: `.tools/security-secrets-verified-20261110.log`. Nonfatal dependency/license analyzer warnings remain; this secret-only scan establishes no dependency vulnerability result and does not cover history, ignored files or binary assets. It resolves the earlier ambiguous shell exit. Rotation of the OAuth client secret exposed in the earlier diagnostic remains unverified.

## GCP follow-up

The previously failing OAuth MCP connection now discovers `run_gcloud_command` and `run_bq_command`, and remote project reads succeed. MyAaptha project `project-5c36c021-87c7-4cfc-833` is ACTIVE, project number `671435485594`. The Compute Engine instance inventory returned an empty list.

This session requested activation of Resource Manager, Compute Engine and Artifact Registry APIs; the subsequent enabled-services list includes all three. Service Consumer Management activation was also requested to inspect the asynchronous status operation; that operation read later failed with an upstream HTTP 500. Successful actual project/instance reads supersede the earlier SERVICE_DISABLED responses for those reads. Artifact Registry inventory timed out after 300 seconds, so registry contents and readiness remain unverified; the following compute-project-info call was not executed after that timeout. Cloud Run was probed during inventory but was not enabled or selected as the deployment target.

Cloud access is no longer the original blocker. This is not a completed deployment: there is no verified application endpoint, scanned immutable release, completed private dependency/secret/TLS setup, confirmed trial credit, or production GIGW clearance. No VM, live DNS record or application rollout was created by these checks. Existing deployment preparation is in [the GCP beta runbook](launch-board/GCP-BETA-2026-11-09.md).
