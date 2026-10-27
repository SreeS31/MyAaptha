# Web, mobile and API synchronization — 6 October 2026

This review covers the canonical Next.js web application, Flutter application and Spring Boot API in CircleNet/MyAaptha. The older reference applications and SV3DDesigns are separate projects.

## Changes

- Added native mobile storage usage, upload-policy details, administrator level editing and user assignments. Open Settings → Storage & uploads → Storage usage & upload limits. The server still enforces roles, quota, file limits and retention.
- Added native new-chat selection, group creation and search across direct/circle messages through the same endpoints used by web. Open Messages → New chat, group & message search. Group membership is restricted to eligible saved relationships.
- Corrected group creation and circle create/update requests with an omitted description, which previously conflicted with the database's nonblank description constraint.
- Finance reporting months use UTC on web, mobile and the API default. Web transaction date inputs display local wall time and submit ISO timestamps, matching native timestamp handling.
- Web diary, circles, health and finance refresh server data while visible and on focus/reconnection. Existing chat polling now also refreshes on focus/reconnection, without overlapping requests. Native health, finance and storage refresh on resume. Account editing forms retain their existing save behavior.
- Updated browser checks for the current conversation controls, collapsed finance form and product landing page. Integration fixtures wait for rate-limit windows and retry HTTP 429 responses; application protection remains enabled. Route auditing now includes the administrator security page. Browser suites store their traces in separate directories.

## Cross-client checks

The new browser test compares responses from browser-cookie and mobile-bearer sessions for 15 account endpoints: session, profile, settings, notification preferences, AI preferences, upload policy, relationships, circles, message preferences, direct conversations, circle conversations, address book, role models, health and finance. It verifies settings writes in both directions, finance creation/deletion while the browser page stays open, and private/admin access rejection.

The opt-in native test uses the actual Flutter authentication and API client against the local preview. It creates synthetic accounts and verifies settings, storage policy, finance, group membership, direct-message search and read-receipt preferences. Ordinary Flutter tests also exercise the new screens and validation.

## Verification

| Check | Result |
| --- | --- |
| Backend tests | 158 tests; zero failures/errors; one existing skipped test |
| Executable API package | Passed after stopping the preview to release its Windows JAR lock |
| Production web build | Passed; existing image-element lint warnings remain |
| Web unit tests | 17 passed, including polling and timezone/day-boundary checks |
| Production browser tests | 12 passed across desktop and mobile |
| Flutter analysis | No issues |
| Flutter tests with live API enabled | 32 passed |
| Explicit native HTTP client verification on final API build | Passed |
| Android preview APK | Built successfully at `mobile/flutter-app/build/app/outputs/flutter-apk/app-debug.apk` |
| Desktop/mobile live integration suite | All 36 distinct cases verified: 32 passed in the main run; the four outdated-assertion failures passed in a focused rerun after correcting the tests |
| Page layout and contrast audit | 28 unique routes and 29 views per viewport; zero horizontal overflow or detected contrast violations on desktop and mobile |

Evidence is in `.tools/sync-api-final-2026-10-06.log`, `.tools/sync-api-package-2026-10-06.log`, `.tools/sync-web-final-2026-10-06.log`, `.tools/sync-web-unit-2026-10-06.log`, `.tools/sync-web-e2e-final-2026-10-06.log`, `.tools/sync-mobile-analysis-final-2026-10-06.log`, `.tools/sync-mobile-tests-final-2026-10-06.log`, `.tools/sync-native-live-2026-10-06.log`, `.tools/sync-mobile-apk-2026-10-06.log`, `.tools/sync-browser-verified-2026-10-06.log` and `.tools/sync-browser-focused-2026-10-06.log`. Route audit details are in `.tools/ui-review-current/desktop/audit.json` and `.tools/ui-review-current/mobile-web/audit.json`.

## Running the checks

Start the isolated local preview using the repository README. From `frontend/nextjs-app`, run `npm run test:unit`, `npm run test:integration` and `npm run test:e2e`. Integration tests create synthetic accounts and may wait for the normal rate limits. Use one integration worker.

From `mobile/flutter-app`, run `flutter analyze --no-pub` and `flutter test --no-pub`. To include the live native test, use `flutter test --no-pub --dart-define=SYNC_API_URL=http://127.0.0.1:8080`. The live test accepts localhost addresses only and makes no paid AI requests.

## Scope and rollout

These checks establish local source/build compatibility and shared account data for the tested workflows. They do not certify every role/data combination, identical web/native feature coverage, production deployment, iOS packaging or physical-device behavior. Existing installed applications must be updated to receive the new native controls. A release requires the intended HTTPS API URL and normal distribution/deployment steps; the local Android preview package targets the host API through the Android emulator address.
