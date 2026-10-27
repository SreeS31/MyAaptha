# Pending-task development — 17 October 2026

View the live local board at **http://127.0.0.1:4317**. Start it again with `powershell -NoProfile -ExecutionPolicy Bypass -File infrastructure/start-launch-board.ps1`. The application preview remains at **http://localhost:3000**.

## Completed locally in this development pass

### M02.4 — Native profile-photo and gallery parity

- Added native upload/change/remove portrait and add/remove gallery controls using the existing profile-media endpoints.
- JPG/PNG/WebP, 5 MB client checks, eight-photo gallery control, removal confirmation, busy/error feedback, cancelled-picker handling and existing image fallback.
- Uses the server's storage policy, malware checks and retention flow. No additional backend photo contract was introduced.
- Resolves profile-media URLs against the configured API host so Android emulators do not interpret server-generated localhost links as device-local services.
- Profile editing and photo operations do not overlap. Photo changes refresh shared profile data.
- Actual native HTTP verification successfully uploaded and removed a portrait and gallery photo against the local API and checked another account's isolation.

Physical Android/iOS acceptance remains open under **M16.3**. This completes the local controls/API parity work, not device certification or store distribution.

### M05.4 — Timeline deletion and reset to source

- Added authenticated, owner-scoped `DELETE /api/timeline/events/{key}` returning 204. Repeated deletion is safe; another account cannot delete the owner's row even with the same event key.
- Web: edit a saved event to choose **Delete event**, or **Reset to source** for a saved override of a current profile/relationship milestone. Confirmation is required and failures leave the saved card available.
- Native: saved cards expose the same Delete/Reset distinction with confirmation.
- Removing a custom event removes it from the timeline. Resetting an override shows its original source milestone. Profile and relationship data is untouched. Unmodified derived milestones do not offer deletion.
- Web mutation guards prevent an older polling/focus response from restoring a removed saved event.

### M03.5 — Discovery data review completed

Traced the generated-looking role-model cards to retained integration-fixture nominations and performed an aggregate-only read-only audit: 29 fixture-pattern accounts, with all 11 nominated role-model accounts matching that pattern. See [review and handover](DISCOVERY-REVIEW-2026-10-17.md). This completes the review task only; no accounts were deleted and no discovery policy was silently changed.

## Readiness fix discovered during live verification

The local scanner had downloaded newer definitions but was still using its older loaded database because its updater had finished before the daemon socket was ready. The API correctly rejected uploads using its existing 48-hour signature policy.

Reloaded the downloaded database and verified real uploads afterwards. Added `infrastructure/check_scanner.py` to local startup: it checks the same freshness window, can request one reload of existing downloaded databases, waits for readiness, and fails startup with an actionable message if freshness remains invalid. It never fabricates a signature date or disables scanning.

Production scanner provisioning, storage and monitoring remain open under **M14.5**.

## Verification

| Check | Result |
|---|---|
| Timeline API and existing media integration | 5 passed; owner isolation, idempotence, source preservation and media behavior |
| Native targeted photo/profile/timeline checks | 6 passed |
| Native regression suite | 37 passed; opt-in live check skipped in ordinary suite |
| Explicit native HTTP live test | Passed; includes actual scanned photo/gallery operations and timeline removal/isolation |
| Web production build | Passed; existing image-optimization advisories remain |
| Browser desktop/mobile integration | All 6 distinct cases verified: 5 passed initially; existing mobile profile reload case passed separately after its wait was made appropriate for server-backed loading |
| Scanner freshness and board-server boundary unit checks | 7 passed |
| Actual scanner readiness | Passed with fresh loaded definitions; upload protection unchanged |
| Android debug preview | Rebuilt successfully with the new photo/gallery and timeline controls; physical-device installation was not performed |

The first upload run failed because the loaded scanner signatures were stale. It passed after the real updated database was loaded. The initial mobile profile browser assertion timed out while the timeline was still loading; its focused rerun passed with a 15-second reload allowance. Neither issue was bypassed in application security.

Evidence logs are under `.tools/launch-board/`: `timeline-api-tests.log`, `mobile-targeted-tests.log`, `mobile-regression-tests.log`, `native-live-tests-final.log`, `web-build-final.log`, `browser-integration-tests.log`, `browser-mobile-recheck.log`, `readiness-tests.log`, `scanner-readiness.log` and `android-preview-build.log`. These logs remain local rather than being exposed wholesale by the board server. Updated package: `mobile/flutter-app/build/app/outputs/flutter-apk/app-debug.apk`; debug builds use the configured development/emulator API URL and are not signed store submissions.

## Remaining scope

Three previously pending tasks are now locally complete: **57 / 86 complete; 29 pending**. These comprise two developed features and one completed data review. Public launch remains unapproved. Cloud setup, real delivery/provider validation, capacity acceptance, physical devices, production recovery, independent reviews and release signing still require their recorded prerequisites. No production deployment, customer-account cleanup or paid AI requests were performed.

Board edits remain browser-local. If a saved edited plan uses an older source baseline, the board shows a new-baseline notice; export edits before choosing Restore baseline. The versioned JSON/status report records the development results independently.
