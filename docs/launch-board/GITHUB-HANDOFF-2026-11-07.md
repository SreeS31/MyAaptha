# GitHub validation handoff - 7 November 2026

Repository: `SreeS31/MyAaptha`. Working branch: `feature/launch-readiness-20261027`.

## Changes

The launch board now reflects 18 modules, 90 tracked tasks, 61 recorded complete and 29 open launch gates. Dated verification reports distinguish local engineering checks from production acceptance. The browser verifier follows the current collapsed-details and source/saved-plan controls while preserving browser edits.

Added `infrastructure/verify_launch_board.py` to run browser verification against an isolated read-only loopback server on an available port. The server is stopped after verification. This avoids relying on an already running preview and exercises hosted source refresh.

GitHub CI now includes feature-branch pushes and manual dispatch. The frontend job runs the hosted-board verifier after its application browser/unit checks. Existing main/develop, pull-request and reusable-workflow triggers are preserved. This change does not add production deployment.

## Validation

- 7 November: all 79 infrastructure regression tests passed in a clean full invocation outside the filesystem sandbox.
- 7 November: the new hosted-board verification command passed, including live refresh, saved-plan preservation, completion guards, import/export and phone-width layouts; zero browser script errors.
- CI YAML parsing and the feature/manual/board-job configuration assertions passed.
- `git diff --check` passed. Protected secret/build directories are ignored and excluded from the publication scope.
- [Earlier application verification](PENDING-WORK-2026-11-06.md): web production build and 12 browser checks passed; backend full invocation reported 249 passed/3 skipped; Flutter full invocation reported 97 passed/2 skipped.
- [Focused real-service integration follow-up](LOCAL-INTEGRATION-COMPLETION-2026-11-06.md): all five previously skipped Redis/OAuth, TLS/S3 and native PostgreSQL/ClamAV checks subsequently ran and passed. Those focused runs are separate from the original full-suite invocations.

Raw local logs, caches, credentials, artifact binaries and signing material are not part of this handoff. GitHub CI results for the pushed commit must be assessed separately from these local results.

## Launch limits

The [29 open launch gates](PENDING-ACCEPTANCE-2026-11-06.md) retain their required cloud/provider, device, operational and independent-review inputs. No completion stage or release approval was changed by this publication preparation.

## GitHub CI follow-up

The first feature-branch CI run passed the frontend, backend, mobile, AI and production TLS smoke jobs, but exposed two platform/tooling failures. Owner-input reconciliation compared raw CRLF bytes with an LF Git checkout; the Trivy action reference did not resolve.

Reconciliation now supports an additive canonical SHA-256 that normalizes only CRLF to LF, while retaining the original captured byte hash. Legacy profiles remain byte-exact. New tests cover Windows/Linux line endings, substantive edits, whitespace, BOM changes, missing files and unchanged approval boundaries. The original owner answers were not changed or re-approved. The full local infrastructure suite now passes **82 tests**.

CI and tagged-release scans pin the verified commit `ed142fd0673e97e23eac54620cfb913e5ce36c25` for the [official Trivy action v0.36.0 release](https://github.com/aquasecurity/trivy-action/releases/tag/v0.36.0). Scan severity and failure thresholds remain unchanged. Both workflow files parse successfully and their action references were checked against the official tag.


## Dependency security remediation

The subsequent GitHub run exposed real dependency vulnerabilities after the scanner could run. The remediation upgrades Next.js and its matching ESLint configuration, sharp and source-map-js. The backend moves to Spring Boot 4.0.9 / Spring Framework 7.0.10, with the managed Tomcat 11 baseline, Jackson 2.21.8 and POI 5.4.1. The old Tomcat 10 and Jackson BOM overrides were removed or replaced.

The backend uses the official Boot 4 Jackson 2 compatibility module and explicitly selects its HTTP converter to preserve existing wire contracts and strict parsing. Flyway and RestClient use the new modular starters; health and test imports follow their Boot 4 locations. A new HTTP regression checks rejection of unknown and duplicate JSON fields before authentication. The compatibility module is deprecated upstream and should be migrated to Jackson 3 in a separate contract-tested change.

The first full migration run exposed cross-context H2 database shutdown: contexts shared one named in-memory database. Test contexts now use distinct UUID-named databases, preventing an evicted context from closing another context's fixture. This changes test isolation only.

Security matrix jobs now finish independently, so a failed scan no longer cancels the other contexts. Severity thresholds and publication gates are preserved.

References: [official Boot 4 migration guide](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.0-Migration-Guide), [Next.js advisory](https://github.com/advisories/GHSA-2464-fhr4-w9xw), [sharp advisory](https://github.com/advisories/GHSA-wq5f-xc86-pv6w), [Spring advisory](https://spring.io/security/cve-2026-47884/).

Local validation: the first 24 focused backend authentication, upload, finance and operational-access checks passed. Frontend unit checks passed all 23 tests (exit code zero). Refreshed Trivy 0.74.0 local scans found zero HIGH/CRITICAL vulnerabilities in the frontend production lockfile and zero vulnerabilities at any severity in the migrated backend dependency descriptors. The patched Next.js 15.5.29 production build passed, followed by all 12 desktop/phone browser, accessibility and CSP checks. After correcting fixture isolation, all 30 affected AI, finance, renewal and authentication tests passed, including the new strict-JSON regression. The hosted launch-board verifier passed again with zero browser errors. The earlier full local migration run failed on the shared H2 fixture and was stopped; it is not reported as passing. The corrected complete suite and production TLS smoke subsequently passed in [GitHub CI run 42344014675](https://github.com/SreeS31/MyAaptha/actions/runs/42344014675) for source commit `05b09279845555d02b7edfbc19f071d5694c43ee`. The full backend invocation reported 253 tests, zero failures/errors and one opt-in S3 skip; the separate local TLS/S3 recovery drill then ran and passed. All nine CI jobs passed, including all three dependency/secret scans. See [final integration evidence](SECURITY-INTEGRATION-2026-11-07.md).
