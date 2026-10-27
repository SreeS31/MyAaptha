# Development continuation — 20 October 2026

Implemented an offline rollback planner for M15.7. It reuses release validation,
normalizes documented resource defaults, requires immutable image digests, rejects
non-image differences (including unknown/new-null settings), prevents input-file
overwrite and records exact image replacements plus configuration hashes.

Plans always retain `releaseApproved: false`, `clusterContacted: false`, unverified
schema compatibility and a pending live rehearsal. The review steps include data,
secrets, OAuth handoffs, staging validation, approval, alerts and recovery timing.
See [usage and operational boundaries](ROLLBACK-PLANNER-2026-10-20.md).

The final infrastructure regression suite passed 52 tests with zero failures/skips (`release-infrastructure-verified-20261020.log`). No cloud
resources, deployed workloads or application data were changed. Current launch
scope remains **18 modules, 89 subtasks, 60 complete and 29 pending**. M15.7 still
requires selected infrastructure, actual monitoring/alert routes and a live rehearsal.

## Full pending-task audit

Audited all 29 pending source tasks. The board now shows a category summary and an exact owner/requirement/next-action row for each task, independent of stale saved browser plans. The generator rejects duplicate or missing audit IDs. The [readable acceptance report](PENDING-ACCEPTANCE-2026-10-20.md) contains the same source requirements. Categories: seven staging, seven provider/model, five device/distribution, five policy/independent-review and five production-operations tasks.

Workspace inspection found an example release configuration, without a selected staging release configuration under infrastructure. The existing local OpenAI key file was not decrypted or used. Android tooling reported zero connected physical devices or emulators; no device IDs or device data were read. Staging, provider, signing and approval references were requested from the owner while independent work continued.

## Fixed Android release signing

The Android release variant previously used the debug signing configuration. It now requires release credentials from ignored properties or environment variables, validates the private signing key/certificate and rejects the standard debug identity. Debug-task planning succeeds without release credentials; release-task planning rejects missing credentials before execution. A manual candidate workflow builds and verifies an AAB with an explicit expected public certificate fingerprint; it does not publish to Play and was not dispatched remotely.

A disposable synthetic identity produced a 72.7 MB release AAB (409.2-second Gradle task). The output was moved out of the normal release-output path into an explicitly synthetic test artifact under .tools. Its private key was deleted. Actual JDK-based verification accepted its pinned certificate, rejected a wrong certificate and rejected an added unsigned entry. The verifier also rejects unsafe/duplicate paths, expired/rejected algorithms, malformed identity input and file mutation during verification. All 52 infrastructure checks passed. See [signing usage and boundaries](ANDROID-RELEASE-SIGNING-2026-10-20.md).

The real JDK output reports self-signed/short-lived synthetic certificate, missing timestamp, unsigned ZIP attributes and JarFile/JarInputStream layout warnings. These observations remain in the verification JSON; layoutReviewRequired is true. The test result proves the local signing/verification path, not production packaging or store acceptance. Release approval and storeSubmitted remain false. Logs: android-debug-plan-20261020.log, android-missing-signing-20261020.log, android-synthetic-bundle-20261020.log, android-bundle-real-cases-20261020.log.

M16.4 now has its coding stage complete, with release testing/owner/store acceptance still open. Coding progress becomes 67/67 applicable (22 N/A); tracked launch closures remain 60/89 with 29 pending. No acceptance gate was closed by substituting a synthetic key or a local environment for its real requirement.

## Final board freshness and documentation

Hosted board pages now check launch-data.json every minute and when the tab regains focus. Source updates refresh an unedited board automatically; saved browser edits remain intact while the source engineering/audit panels update. Offline-file snapshots make no network requests. Failed refreshes retain the loaded evidence and show an availability message. An open edit dialog defers refresh. Browser verification passed both live source replacement and preserved local edits, all 29 audit rows, normal interactions, import/export and expanded 390px layouts with zero script errors. Load the new page once to enable this behavior; already-open older HTML cannot acquire the new JavaScript until reloaded. Evidence: board-live-refresh-20261020.log.

The synthetic Android-debug identity was rejected by release-task planning, confirming that supplied debug credentials do not bypass the guard (android-debug-identity-rejected-20261020.log). All test private keys were removed. The manual workflow structure was checked locally and never dispatched.

Handbook v1.3 and its 71-page PDF were regenerated with the signing, rollback and acceptance boundaries. Source references remain 39 controllers, 229 HTTP mappings, 28 web pages, 67 declared tables and 106 FK edges. Validation found zero broken local links, 21 valid SVGs, zero broken images/page errors and no desktop/390px overflow. Evidence: release-corporate-validation-20261020.log and release-corporate-render-20261020.log.

App, API health, helper readiness and launch board returned HTTP 200. No application runtime code or existing API/web/debug-APK artifact was replaced in this batch; the synthetic release bundle has its own explicit test-only verification record. External provider, store, policy and staging gates still need the owner-supplied inputs listed in the audit.

## Operational authorization and dependency recovery continuation

Protected Actuator endpoints now authenticate bearer sessions and require administrator access. The optional metrics credential is limited to GET /actuator/prometheus and cannot authenticate account or other operational routes. Public probes remain usable with invalid bearer headers; production health details remain hidden. Compose passes the optional secret only to the backend. See [operational guide](OPERATIONAL-METRICS-2026-10-20.md).

Seven focused Java tests passed after correcting test-only Redis health and disabled metrics-exporter fixtures. The earlier broad run passed existing authentication, recovery, production-guard and scaling tests; its three new-fixture failures were corrected and rerun. The API package succeeded. No live account was promoted.

The packaged production-profile TLS smoke passed actual disposable PostgreSQL and Redis stop/start checks: readiness goes DOWN/503, liveness and authenticated metrics stay available, and readiness recovers. The first run exposed Docker reassignment of automatically allocated host ports; a separate reproduction confirmed it. Disposable fixtures now explicitly bind reserved localhost ports and assert restart mapping stability. Application reconnection behavior was unchanged. The successful smoke also checked migrations/schema, authentication refresh, authorization/isolation and encrypted financial storage. This is local dependency recovery, not production HA, backup/PITR or RPO acceptance.

Passing evidence: operational-access-focused-20261020.log (7 Java tests), operational-api-package-20261020.log, operational-tls-verified-20261020.log, operational-infrastructure-final-20261020.log (53 tests), operational-account-browser-20261020.log (2 desktop/phone-browser synchronization scenarios), and operational-native-live-20261020.log (1 explicit native HTTP test). All temporary TLS/dependency fixtures were cleaned. The local preview restarted with the rebuilt API and refreshed scanner signatures.

M15.7 application coding prerequisites are now complete; real collector/alerts, selected staging and live rollback acceptance remain open. Current source totals: 68/68 applicable coding (21 N/A), 68/89 testing, 60/89 integration; 60 tasks closed and 29 pending. No provider, device, policy or deployment approval was substituted with local evidence.

Final continuation checks: launch-board desktop/mobile interactions, source refresh and all 29 acceptance audit rows passed with zero browser errors (operational-board-20261020.log). Handbook v1.4/PDF validation passed: 71 pages, 21 SVGs, no broken local links/images or desktop/390px overflow. App, API health, helper readiness and independent launch board each returned HTTP 200.

Artifact verification correctly rejected the old API fingerprint, refreshed the local API/debug-APK/assembled-web identity record, and verified all current bytes match. releaseApproved remains false. Shared owner/external dependencies are mapped in [owner inputs](OWNER-INPUTS-2026-10-20.md); these are not repeated requests for coding permission.

## Release dependency preflight continuation

Implemented infrastructure/preflight_release.py for M15.4: read-only validation of the existing immutable-release JSON contract, five protected Compose secret files and provider CA format. It makes no network requests, writes no files, reports no input values/raw exception messages and never approves a release. Missing/oversized/malformed inputs, placeholders, weak key formats, duplicate field-key IDs and missing active keys fail closed. Secret-manager Kubernetes mappings and live identity/connectivity/CA expiry remain separate checks.

All five new focused tests passed. The actual default-layout run reported seven unmet prerequisites: selected release configuration, five production secret files and database CA. Preview/development credentials were not copied into production. See [usage and exact boundaries](RELEASE-PREFLIGHT-2026-10-20.md). This prerequisite tool does not close M15.4 provisioning acceptance or alter the 60/89 launch closure count.

Release-preflight final verification: all 58 infrastructure tests passed, including five new prerequisite checks; updated launch-board desktop/mobile interaction, acceptance audit and source-refresh verification passed with zero browser errors (preflight-infrastructure-20261020.log, preflight-board-20261020.log). No runtime artifact, external resource or customer data changed in this continuation.
