# Security and GIGW release review — 10 November 2026

Status: local checks completed as recorded below; cloud rollout blocked; not deployed. This review does not establish whole-application security, GIGW certification or production acceptance.

Latest follow-up: [GIGW security feature matrix and working GCP connection](GIGW-SECURITY-CHECK-2026-11-10.md). MCP access now works, required APIs were enabled, the project is ACTIVE and its VM inventory is empty. Earlier connection failures below are historical evidence.

## Scope and evidence

Canonical targets are `backend/spring-boot-app`, `frontend/nextjs-app`, `ai/agent-service`, `mobile/flutter-app` and `infrastructure`. The legacy MySQL scaffold is excluded from release inputs.

Fresh local results:

| Check | Result | Local evidence |
| --- | --- | --- |
| Infrastructure unit suite | 91 passed | `.tools/security-infrastructure-20261110.log` |
| Frontend unit suite | 23 passed | `.tools/security-web-unit-20261110.log` |
| AI service suite | 11 passed | `.tools/security-ai-20261110.log` |
| Production npm dependency audit | Zero reported known vulnerabilities | `.tools/security-npm-audit-20261110.json` |
| Backend Maven verify | BUILD SUCCESS; 258 run, zero failures/errors, 3 skipped | `.tools/security-backend-20261110.log` |
| Web production build | Passed; existing lint warnings remain | `.tools/security-web-build-20261110.log` |
| Production browser suite | All 14 cases passed; runner hung during Windows teardown and was interrupted | `.tools/security-web-e2e-20261110.log` |
| Flutter tests | 102 passed, 2 skipped; cached dependencies, `--no-pub` | `.tools/security-mobile-offline-20261110.log` |
| Production-profile TLS smoke | Passed against disposable PostgreSQL/Redis with synthetic accounts | `.tools/security-tls-smoke-20261110.log` |
| TLS S3-compatible recovery drill | Passed; one opt-in test, synthetic data only | `.tools/security-s3-recovery-20261110.log` |
| Offline tracked-source secret scan | Follow-up explicit Docker exit 0; zero secret findings; nonfatal analyzer warnings | `.tools/trivy-cache/security-secrets-verified-20261110.json`, `.tools/security-secrets-verified-20261110.log` |

The npm audit covers production npm packages only, not Java/Python dependencies, container operating systems, unknown vulnerabilities or application logic. Browser tests include mocked API responses; they do not establish live end-to-end backend/provider acceptance.

Backend skips are the opt-in S3 recovery drill and two Redis-dependent test classes. These are not covered by the default successful Maven run. Initial sandbox attempts failed to access Maven/Flutter settings; the successful runs used the existing caches outside the sandbox. The production browser cases ran against the fresh successful web build; their hung teardown is not a clean runner exit.

The production-profile TLS smoke subsequently verified real migrations/schema validation, registration/login/refresh, administration denial, cross-user circle isolation, encrypted financial round-trip/isolation and ciphertext in actual PostgreSQL storage. Anonymous/member metrics access was denied and scoped scraping succeeded. Simulated PostgreSQL and Redis outages withdrew readiness while retaining liveness/metrics; readiness recovered after restarting the disposable dependencies. Fixtures cleaned up their own containers. This is local runtime evidence, not a GCP infrastructure audit.

The separate TLS S3 recovery drill covered the real storage adapter, signed reads, denial of unsigned reads and untrusted TLS, server-side encryption, versioned deletion, matching restored bytes and lifecycle configuration round-trip. The disposable service was removed. It did not measure elapsed automatic expiry or establish provider-level production lifecycle acceptance.

The offline Trivy scan used a snapshot of 1,167 current tracked text/code files, excluding binary assets and symlinks. It did not inspect Git history, ignored files, external secrets, built images or dependencies for vulnerabilities. Whole-workspace scanning was stopped after making slow progress through local generated artifacts. The retained replacement scan produced a parseable report with zero secret findings, but the shell returned exit 1; Maven dependency-resolution and Python license-analyzer warnings were also emitted. Treat this as limited evidence, not clean comprehensive scanner acceptance. Full clean CI secret/dependency/image scans remain required.

Follow-up: the scan was rerun using direct subprocess capture, including the current banner-suppression edits and review documents. Actual scanner exit was 0 and zero secrets were reported. Nonfatal dependency/license analyzer warnings remain. This resolves the earlier ambiguous shell status for secret scanning; its scope exclusions and outstanding dependency/image vulnerability checks remain unchanged.

## Findings and changes

- Landing-page accessibility coverage previously discarded every axe violation except critical ones. Changed the existing WCAG 2.1 A/AA check to require zero detected violations. Manual keyboard, screen-reader, authenticated-page and document testing remain required.
- Source inspection found nonce-based CSP, security response headers, separate member/admin endpoint rules and origin/custom-header checks on cookie-authenticated mutations. Spring's built-in CSRF is disabled, but `WebCookieAuthenticationFilter` implements browser mutation protection; the disabled setting alone is not evidence that CSRF protection is absent. Live proxy/origin acceptance remains required.
- `/privacy` is an authenticated blocked-account screen, not a public privacy policy. A support email on the landing page does not replace a published, approved privacy policy. Public privacy/security/accessibility policies and terms need owner-approved wording, actual data practices and responsible contacts before publication.

## GIGW 3.0 conformity gaps

Official references: [GIGW cybersecurity](https://guidelines.india.gov.in/security-guidelines-and-attributes/), [scope](https://guidelines.india.gov.in/scope-and-objective/), [new features](https://guidelines.india.gov.in/new-features-of-gigw-3-0/), [STQC certification](https://www.stqc.gov.in/en/website-quality-certification-0).

GIGW targets Indian government websites/apps. Apply its applicable controls here as the requested benchmark; do not represent a private service as a government website or claim certification from automated checks.

| Area | Evidence still required |
| --- | --- |
| Security audit clearance | Eligible NIC/STQC/CERT-In empanelled independent audit and clearance before production hosting under the GIGW framework |
| Accessibility | WCAG 2.1 AA assessment across public/authenticated web, mobile, forms and documents; manual assistive-technology checks |
| Policies and ownership | Approved public privacy/security/accessibility/content policies, terms, contact and grievance process, accountable website manager and review schedule |
| India hosting | Verified India placement for application, storage, backups and applicable processing; Mumbai in the proposed beta plan is not deployment evidence |
| Infrastructure security | Actual least-privilege IAM, private database/cache/object-store connections, TLS, certificates, secrets, edge/WAF rules, patching and complete image/dependency scans |
| Lifecycle and incidents | Monitoring/alert delivery, protected audit logs, retention and incident response aligned with applicable CERT-In requirements and legal review |
| Recovery | Isolated provider-level restore drill, backup/PITR, documented rollback and accepted recovery objectives |
| Application acceptance | Real synthetic-account session, authorization/IDOR, upload/antivirus, messaging, health/finance, provider and deletion/consent tests in staging |

## Deployment blockers

Read-only GCP CLI checks with the installed Python interpreter found no active account and no selected project. Existing project reference: `project-5c36c021-87c7-4cfc-833`, number `671435485594`. A project ID does not grant deployment access. Owner authentication and actual project/billing/trial access are required; never send credentials in chat.

`python infrastructure/preflight_release.py infrastructure/release.json` failed all seven checks in its default Kubernetes-release/Compose-secret layout: release JSON, database password, Redis password, JWT key, field-encryption keys, MFA key and database CA. This does not prove secrets are absent from every other local or remote store; it proves the selected release layout is not ready.

No cloud resources, DNS records or deployed application were changed. Next steps after authentication are read-only project/billing/resource discovery, preparation of an isolated staging release with scanned immutable images, private dependencies and TLS, live staging acceptance and independent security clearance, then production rollout with rollback evidence. Existing scripts must not bypass TLS, antivirus, secret-strength or migration gates to obtain a public URL.

### Follow-up: existing MCP setup verified

After the owner reported completing sign-in and MCP setup, a read-only diagnostic found an enabled `google-cloud` server in the user Codex configuration, using `https://cloudcli.googleapis.com/mcp` with the intended quota-project header. `codex mcp list` reports OAuth, and the app-server status request reports `authStatus: oAuth`. However, tool discovery fails with `MCP startup failed` and `HTTP 403`; the returned usable tool catalog is empty. This corrects the earlier impression that no MCP configuration existed. The separate local gcloud CLI still returns an empty account list and cannot describe the project.

The exact reason for the HTTP 403 is not established. Verify Cloud CLI Execution API enablement (`cloudcli.googleapis.com`), the connected identity's MCP Tool User role (`roles/mcp.toolUser`), required deployment permissions, and the authorized cloud-platform OAuth scope. See [Google's setup requirements](https://docs.cloud.google.com/sdk/use-gcloud-mcp). Do not assume sign-in must be repeated or grant broad roles without checking existing access. No cloud provisioning or IAM changes were made by this diagnostic.

A diagnostic mistakenly printed the configured OAuth client secret in tool output. Its value is not included in this report or committed files. Rotate that client secret and update the existing local OAuth configuration; subsequent diagnostics redact values and expose only connection status/errors.
