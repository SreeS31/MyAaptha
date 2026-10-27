# Development results — 18 October 2026

Live application: **http://localhost:3000**. Launch board: **http://127.0.0.1:4317**.

## Delivered: paginated moderation queue

Web, native and API now share a status-filtered cursor endpoint that reaches older reports beyond the previous 200-record ceiling. Native has review/resolve/dismiss controls; both clients disclose that notes are reporter-visible and submit nothing when the notes dialog is cancelled. Successful decisions retain pagination context. Access denial clears loaded report content.

The V69 index migration passed against the preserved local PostgreSQL preview. The legacy endpoint remains compatible with earlier clients. See the [contract, workflow and acceptance scope](MODERATION-QUEUE-2026-10-18.md).

| Verification | Result |
|---|---|
| Database pagination and access tests | 3 passed; more than 200 reports, new arrivals, status filtering, bounds and member/report-owner isolation |
| HTTP contract tests | 2 passed; query binding, JSON cursor shape and denial before querying |
| New native widget scenarios | 3 passed; pagination/filter reset, cancellation/saved notes and role-denial cleanup |
| Native regression | 50 passed; opt-in live case skipped in the ordinary run |
| Explicit native live API scenario | Passed; real member queue denial and existing shared-account flows |
| Desktop and phone-browser scenarios | Both passed; real cookie/bearer denial and synthetic administrator UI contracts |
| Native analysis | No issues |
| API, web and Android debug builds | Succeeded |

Administrator browser branches use synthetic responses. No live account was promoted to administrator, and no real user report was moderated. The actual administrator database query and access rules are tested in the isolated backend suite. Build identities were refreshed in `.tools/launch-board/build-identities.json`; this does not approve production promotion.

## Board scope and remaining gates

**M08.5, M09.5 and M15.9** explicitly track three newly identified local engineering deliverables. Current scope: **60 complete / 89 tracked, with 29 pending** (original scope: 86). The moderation batch alone reached 58/87; the two subsequent deliverables reached 60/89. These are scope additions, not external approvals.

**M08.4 operating-policy approval remains pending.** Staffing, response procedures, appeals, retention guidance and approval have not been supplied. The queue visibility limitation described in that review draft is now addressed. Other cloud/provider/device/legal/security release gates remain unchanged.

Logs: `.tools/launch-board/moderation-queue-*.log`. The latest-source panel is shown even if a browser retains an older edited plan; edits are preserved rather than silently overwritten.

## Delivered: manual health-entry parity and preserved drafts

Web and native now offer multi-measurement entry with matching API limits, date and reference-range validation, row removal and busy controls. Failed saves preserve entered values and bring errors into view. Exact-limit manual input is stored without truncation. See [health-entry contract and limitations](HEALTH-MANUAL-ENTRY-2026-10-18.md).

Verification: 11 focused backend checks passed; 53 native regression checks passed (one opt-in live case skipped), then all three dialog tests passed after final UX polish. Explicit native live HTTP checks passed. Two final desktop/phone entry scenarios passed, alongside four existing health-input/consent scenarios. Native analysis, API packaging, final web production and Android debug builds succeeded. This prevents concurrent clicks; it does not provide server idempotency after an unknown network outcome.

## Delivered: complete local web-bundle verification

Version 2 records contain every standalone web file hash, a canonical bundle hash, and API JAR/debug APK identities. Runtime cache is excluded; missing required assets, unsafe links, changed bytes and changed paths fail verification. All 22 infrastructure tests passed. The actual 2,085-file bundle was recorded and matched. A previous record correctly rejected the rebuilt artifacts before the final record was refreshed. See [commands and release scope](LOCAL-BUILD-IDENTITIES.md).

Logs: `.tools/launch-board/health-entry-*.log`, `artifact-bundle-regression-final.log`, `artifact-old-record-verification.log` and `artifact-final-verification.log`. No paid provider calls, real messages, production deployment or approval were performed. M09.4 and M15.8 remain open.

## Prepared: stronger-model evaluation (M12.6 still pending)

Added a ten-case synthetic review set and an offline importer/comparison tool. Knowledge and case fingerprints prevent stale comparisons; completeness, citations, human rubric scores and usage are checked. Reports compare supplied costs, tokens and latency without retaining answer text. Eight new tests and the complete 30-test infrastructure suite passed. The preparation command succeeded against the actual current help articles. No provider was called, no actual answer quality was accepted, and no retry setting changed. See [operator workflow and limitations](HELP-MODEL-EVALUATION.md). Counts remain 60/89 because this preparation does not complete M12.6.

## Hardened: portable recovery scripts (M15.6 still pending)

Backup now validates retention/source, publishes unique complete files with checksums and preserves older backups on failure. Restore requires a checksum and an accessible target with no user relations before transactional import. Seven operational simulations and all 37 infrastructure tests passed. A disposable real PostgreSQL 17 drill restored and matched two synthetic rows, then rejected a second restore into that populated target. The test container was removed. No application database was touched. Cloud/PITR/media recovery and measured representative RPO/RTO remain pending. See [recovery evidence and boundaries](RECOVERY-GUARDS-2026-10-18.md). Counts remain 60/89.

## Refreshed: corporate documentation

Corporate handbook version 1.1 now reflects 18 October implementation, with current timeline deletion, native photo parity and the new moderation/health/recovery/evaluation contracts. Source extraction records 39 Java controllers, 229 HTTP mappings, 28 web pages, 67 declared tables and 106 explicit foreign-key edges. Rebuilt HTML and 71-page PDF passed desktop/390px checks with zero overflow, broken images or script errors; all local links and 21 SVGs validated. This maintains existing documentation tasks rather than increasing completed-task totals. Logs: `corporate-oct18-render.log`.

## Fixed: timeline quota and same-key save races

Owner-scoped transactional database locking now serializes saved timeline mutations across API processes. At 499 events, two different new keys yield one success and one quota rejection; simultaneous saves of one new key both succeed with a single row. Existing-key edits remain allowed at 500. All 17 targeted timeline/health/trust backend checks passed and the API package succeeded. This maintains M05.1; launch closure totals remain 60/89. See [concurrency evidence and last-write semantics](TIMELINE-CONCURRENCY-2026-10-18.md).

Final timeline verification: desktop and phone-browser removal/reset scenarios both passed against the restarted PostgreSQL preview; the explicit native shared-account HTTP scenario passed. Final artifact verification rejected the previous JAR record, then matched refreshed identities. App, API `/api/auth/health`, helper readiness and board returned HTTP 200. Logs: `timeline-concurrency-browser-final.log`, `timeline-concurrency-native-live.log`, `timeline-artifact-verification-final.log`, `development-16-board-final.log`.

## Continued: contact permission parity (M04.5 physical acceptance pending)

Both native contact flows now share granted/limited permission handling, deny reads/uploads for other statuses and skip reading when a permission request returns after leaving the screen. The organizer guards duplicate requests and skips empty analyses. Eleven new plugin-channel checks and all 64 native regressions passed (one opt-in live case skipped); analysis is clean. The explicit native live API case then passed selected-contact persistence across sessions, account isolation, cleanup and no automatic relationship creation. Desktop/phone-browser address-book imports both passed. See [permission behavior and physical-device matrix](CONTACT-PERMISSIONS-2026-10-18.md).

M04.5 now records its implemented coding stage; its physical testing/integration acceptance remains open. Source coding progress is 65/65 applicable checks (24 N/A), testing remains 68/89 and integration 60/89. Closed-task totals remain **60/89**, with 29 pending. No new task was added and no device acceptance was fabricated.

Contact continuation build: Android debug APK succeeded. Handbook HTML/PDF now includes the permission parity row and passed rendering validation. Board verification passed with zero browser errors, and app/API/board returned HTTP 200. Logs: `contact-permission-android-build.log`, `contact-permission-corporate-render.log`, `contact-permission-board-final.log`.

Final artifact checks: the previous build record rejected the changed APK; refreshed API/web/debug-APK identities matched successfully. `releaseApproved` remains false. Evidence: `contact-permission-old-artifact.log`, `contact-permission-artifact-record.log`, `contact-permission-artifact-final.log`. The initial scan was slow and the attempted process stop failed; the original verification workflow subsequently completed successfully without stopping application services.

## Continued: OAuth completion, cancellation and expiry

M04.4 now records local coding for matching web/native/API behavior: configured-provider availability, retryable metadata lookup, polling only pending 404s, terminal denial/failure, successful empty results and explicit cancellation. Late responses cannot reopen cancelled attempts. The callback rechecks sensitive-data/AI permission before provider reads and before analysis; scheduled maintenance clears expired pending/results even without client activity. Private-book result shape remains compatible. See [completion contract and staging limits](CONTACT-OAUTH-COMPLETION-2026-10-18.md).

All 12 targeted backend checks and API packaging passed. Native analysis is clean; all 82 native regressions passed (one opt-in live skip), and the debug APK built successfully. The initial browser cases completed their functional branches but found a primary-hover contrast defect (1.31:1); the shared hover rule was corrected to the intended light-blue/dark-text palette and the web production build passed. Final browser hover/focus, live native and artifact checks are recorded below when complete.

M04.4's real-provider/staging testing and integration remain open. Coding checks are now 66/66 applicable (23 N/A), testing remains 68/89 and integration 60/89. Task closures remain **60/89 with 29 pending**, without adding new task scope or claiming a real provider activation.

Final OAuth checks passed: both desktop and phone-browser scenarios, including availability failure/retry, blocked popup without an API attempt, 422/403/legacy terminal results, empty success, cancellation, late-start suppression, review-before-persistence and hover/focus accessibility rules. Actual native HTTP verification passed provider metadata, pending-result 404 and existing persistence/isolation flows. Scheduled idle cleanup is covered in the final 12-test backend suite. Final API/web/APK builds succeeded. No real provider sign-in, cloud deployment or approval was performed.

The shared primary-action accessibility regression passed both layouts across circles, timeline and health, checking hover/focus contrast, accessible names, keyboard focus and viewport fit. This adds targeted local evidence to M16.6 without closing the full staging release suite. Final web/API/debug-APK identities matched; release approval remains false. Logs: `primary-action-accessibility.log`, `contact-oauth-artifact-verified.log`.

Final continuation readiness: launch-board interaction verification passed with zero browser errors; app, API health, helper readiness and launch board all returned HTTP 200. Corporate documentation validation passed after regeneration. Latest evidence logs: `contact-oauth-board-final.log`, `contact-oauth-artifact-verified.log`.

## Continued: atomic shared-state consumption prerequisite

The ephemeral-state interface now supports atomic removal of a validated snapshot. Redis uses one Lua comparison/deletion; the local fallback uses its monitor. Concurrent consumers have one winner, stale/wrong values preserve replacements, expiry prevents consumption and Redis errors fail closed. Development memory now prunes expired state every minute without subsequent reads. All 17 targeted state/OAuth checks passed, including a disposable Redis instance with two independent clients and no skipped tests. The test container was removed. API packaging and launch-board interaction verification passed with zero browser errors.

This is M04.4 infrastructure progress, not its encrypted OAuth state migration: contact pending/results still use process-local maps. Restart/multi-replica, actual provider, device and staging acceptance remain pending. No new task or closure was added: **60/89 complete, 29 pending**. See [shared-state contract and boundaries](SHARED-STATE-ATOMIC-2026-10-18.md). Logs: `shared-state-atomic-final.log`, `shared-state-api-package.log`, `shared-state-board.log`.

Final shared-state continuation readiness: app, API health, helper readiness and launch board all returned HTTP 200 after restart. Refreshed API/web/debug-APK identities matched; releaseApproved remains false. Evidence: shared-state-preview-start.log and shared-state-artifact-verified.log.
