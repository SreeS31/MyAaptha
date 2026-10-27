# MyAaptha local release validation — 23–24 September 2026

Scope: the canonical PostgreSQL API (`backend/spring-boot-app`), web
(`frontend/nextjs-app`), AI (`ai/agent-service`) and Flutter client
(`mobile/flutter-app`). The smaller reference scaffold is not a release target.
Existing staged and unstaged user work has been preserved.

## Local test access

- Web: http://localhost:3000 — choose **Create an account** on the sign-in page.
- API: http://127.0.0.1:8080/api/auth/health.
- AI readiness: http://127.0.0.1:8081/api/v1/ready.
- Restart command: `powershell -ExecutionPolicy Bypass -File infrastructure/start-local.ps1 -SkipBuild` after stopping the existing preview processes.
- Stop command: `powershell -ExecutionPolicy Bypass -File infrastructure/stop-local.ps1`.
- New preview PostgreSQL/Redis containers use loopback ports 55432/56379 and a
  separate persistent volume. Existing development data has not been replaced.
- Login follow-up on 24 September: the initial preview contained only test
  accounts. Restored all 32 legacy accounts into a separate database named
  `myaaptha_restored_20260924` inside the preview container. The original legacy
  database and the initial preview database were preserved. The launcher reads
  `.tools/preview/database.txt` so restarts retain this database selection;
  `-Database NAME` overrides it for that launch.
- On the restored copy only, reconciled seed migration V2 after verifying its
  stored checksum exactly matched the current script with the old brand strings.
  Applied migrations V47–V57 successfully. No password reset was performed.
- Login errors now distinguish unavailable services and rate limits from invalid
  credentials. Browser synchronization coverage now signs in using a saved email.
- Follow-up verification: all 32 original account identities/password hashes
  matched the restored copy exactly; the running API connects to that copy.
  Web rebuild passed and all 8 desktop/mobile-browser integration checks passed
  (email sign-in and data synchronization, plus HTTP 400/429/503 error handling).
  Evidence: `.tools/login-restored-integration.log`,
  `.tools/web-login-fix-build.log`, `.tools/preview/restore-startup.log`.
- This URL works on this computer. It is not a public deployment or a URL that
  can be opened directly on another phone/computer.
- Android emulators use the same API through `http://10.0.2.2:8080` by default.
  Physical-device networking, iOS signing and store releases are separate checks.

## Changes

- Source branding scan found no remaining old-brand references. Existing display
  names, application packages and assets use MyAaptha. The checkout directory was
  preserved to avoid breaking existing tooling paths.
- Fixed ordinary-member access to AI preferences/approval decisions, health-report
  deletion, social-post editing, notification-device removal and trusted-person
  removal. Service-level ownership checks and administrator-only APIs remain in force.
- Batched circle-page author/profile/reaction/read-count lookups. The previous
  per-message lookups held read-receipt insert locks long enough to fail a concurrent
  two-replica check under local load.
- Batched direct-message sender/profile/reply/reaction lookups to reduce database
  connection occupancy under load.
- Web and mobile now have independent sessions. Login, refresh and logout affect
  the corresponding session; password recovery still revokes all sessions.
  Refresh rotation atomically consumes the stored token fingerprint exactly once.
- Native mobile refreshes expiring access tokens with one shared refresh request
  for concurrent API calls and persists the rotated session securely. Ordinary
  member sign-in no longer calls an administrator-only dashboard. Administrator
  sign-in can submit an authenticator code.
- Android debug networking permits HTTP only for localhost and the emulator host
  alias. Release networking continues to require HTTPS.
- Fixed AI blank-query matching, duplicate suggestions based on empty names,
  incorrect email punctuation normalization and missed reciprocal spouse links.
  Bounded candidate field lengths protect similarity comparisons from oversized inputs.
- Updated the isolated scaling runner to use certificate-verified PostgreSQL and
  TLS Redis, ephemeral encryption keys and the current production configuration.
  Included actual circle-message pages in the load mix.
- Added a reproducible local launcher and live desktop/mobile-browser checks for
  browser-cookie and mobile-bearer API synchronization.

## Verification

Completed checks:

| Check | Result |
| --- | --- |
| API verification and packaging | 106 passed, zero failures/errors/skips; real Redis included |
| Web production build | Passed; existing image-optimization lint warnings |
| Desktop/mobile browser checks | 8 passed, including accessibility, CSP and relationship views |
| Frontend regression tests | 7 passed |
| AI tests | 10 passed |
| Flutter analysis | No issues |
| Flutter tests | 15 passed, including ordinary-member login and concurrent session refresh |
| Android debug APK | Rebuilt 24 September at 21:32 IST with current fixes; `mobile/flutter-app/build/app/outputs/flutter-apk/app-debug.apk` |
| Live desktop/mobile-browser synchronization | 2 passed: sign-in, private finance in both directions, shared AI preferences and local contact organization |
| Release-configuration tests | 6 passed |
| npm production dependency audit | 0 reported vulnerabilities |
| Production-profile TLS smoke test | Passed: migrations, schema/startup, authentication, ownership isolation and financial ciphertext in real PostgreSQL |

Final web/API/AI HTTP checks returned 200. Only the preview PostgreSQL and Redis
containers remain running. The Android build succeeded with Kotlin-plugin migration
and SDK XML-version warnings; upgrading that toolchain remains release maintenance.
No installed-device or iOS run was performed.

## Capacity interpretation

The requested target is **300,000 registered accounts**, not simultaneous users.
Database-size tests and sustained traffic tests answer different questions. The local
test uses synthetic accounts, message histories, two API replicas and shared Redis.
Its configured workload is 50 authenticated read requests/second for two minutes,
with p95 below 1.5 seconds, failure rate below 1% and zero dropped iterations required.
This is not a production soak/failover test or a measurement of 300,000 concurrent users.
An interrupted setup run and a subsequent concurrent-read failure are excluded from
successful capacity evidence; the latter drove the circle-query fix.

The first completed 50-request/second run failed: 5,735 requests, 4.14% HTTP
failures, p95 3.71 seconds and 266 dropped iterations. Android compilation was
running on the same laptop. This remains a failed result, not a capacity pass.
Direct-message batching and a repeat run without Android compilation followed.

The next cold run completed 5,853 requests: 0.171% failed, p95 1.774 seconds,
148 dropped iterations. It failed the latency and zero-drop gates. A subsequent
run after 30 seconds of conditioning completed 5,976 requests with zero HTTP
failures and p95 403 ms, but dropped 25 iterations and therefore also failed.
The final harness preallocates all 100 virtual users to avoid allocating them
during measurement; the original acceptance thresholds are unchanged. A setup
attempt that timed out while registering fixtures is not capacity evidence.

The final repeat also timed out at the 15-second fixture-registration request
before the load phase. No passing final load result was produced. The cause of
that setup timeout has not been isolated; do not attribute it to the laptop alone.

**Capacity gate: not passed.** The database-size and two-replica functional checks
demonstrate operation with 300,000 synthetic registered accounts, 340,000 direct
messages and 100,500 circle posts. They do not certify acceptable production
capacity. The measured traffic uses 19 active test sessions and four authenticated
read endpoints, not 300,000 simultaneously active users or the entire application.
Before launch, repeat cold and warmed traffic tests on intended hosting, include
representative writes/uploads/AI calls and a longer soak, and resolve all failed
latency/drop gates without weakening their thresholds.

Local evidence is retained under `.tools/`: `api-current-tests.log`,
`mobile-analysis-current.log`, `mobile-tests-current.log`,
`mobile-build-current.log`, `live-sync-current.log`,
`production-smoke-current.log`, `scaling-current.log`, and the summaries in
`scaling-previous/`, `scaling-cold-final/`, `scaling-warm-underallocated/`.
Disposable load-test containers and bearer-token fixture files are removed by
the runner. The preview database remains available for local testing.

## AI and deployment dependencies

Search ranking, duplicate detection, family insights, profile enrichment and contact
organization run locally as deterministic assistance. They do not require a paid
model endpoint. Sensitive-data features retain explicit consent and review controls.

Health-document model analysis requires a configured provider API key and has not
been verified against a live provider in this pass. Contact-provider OAuth, SMS phone
verification/recovery, notification delivery and actual audio/video device behavior
need their real integrations and device checks. Future roadmap features such as
provider booking and voice assistance are not represented as implemented.
Native phone-verification/recovery enrollment also needs a complete device flow
before enabling the production SMS requirement. The browser/bearer synchronization
test does not substitute for an installed-app end-to-end device test.

Public deployment still needs actual hosting/DNS/TLS, managed database/Redis,
private object storage and upload scanning, secrets, signed mobile releases,
current final-container scans, backup/restore and operational checks, and representative
staging load/failover evidence. The local checks alone do not authorize a claim that
the application is fully production-ready. No cloud resources or third-party messages
were created, and no production load test was run.
