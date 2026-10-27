# Bills, warranties and renewal reminders - 24 October 2026

The Finance menu now includes owner-private bills, warranty and service-plan records, optional scanned receipts, due/expiry dates, notes, INR amounts, time zones, pause, archive, renewal and confirmed deletion. Web and Flutter use the same eight API mappings and PostgreSQL migration V70. Users see saved data by default and open an editor only when adding or editing.

Reminders are durable in-app notifications at 9am in the saved zone, 30, 15, 7, 3 and 1 day before expiry. Existing channel preferences, quiet hours, preview privacy and provider retry dispatch are reused. Per-record row locking and cycle/milestone uniqueness prevent duplicate notification creation. Changing expiry starts a new cycle; pause/archive/delete cancel pending deliveries and superseded notices fail the delivery-time guard. Missed past dates are skipped. Renewing does not create a payment transaction.

Receipts use existing upload quotas, retention controls, type checks and ClamAV scanning. Owner-only downloads return no-store; foreign account operations return 404. Client writes whitelist editable fields, preserving strict server unknown-field validation. Collections are bounded to 1000 records per user.

## Verified scopes

- 19 focused backend tests passed: RenewalServiceTest (7), RenewalControllerTest (2), FinanceMonthBoundaryTest (2), FinanceInputContractTest (1), WebhookDeliveryContractTest (4), MediaDeletionTest (3). Log: .tools/launch-board/finance-renewals-state-backend.log.
- Three native unit/widget cases passed: authenticated multipart/CRUD contract, read-only field filtering, add/edit/pause/renew/archive/confirmed deletion, and invalid empty-form denial. Log: .tools/launch-board/finance-renewals-state-native-final.log.
- Native analysis reported no issues for the new screen, API client and two test files. Log: .tools/launch-board/finance-renewals-state-analysis-final.log.
- A real native HTTP client passed against local PostgreSQL and ClamAV: second-session sync, receipt bytes, owner isolation, renewal/pause, removal and a real minute-scheduler one-day in-app notification. The synthetic account disabled all external channels before the scheduler check; its notification had no external deliveries. Fixture records/receipts were removed in finally. Log: .tools/launch-board/finance-renewals-state-live.log.
- Desktop/phone UTC-month regression cases passed. The new phone renewal browser flow passed, and the desktop flow passed its focused rerun in 9.5 seconds after an earlier timeout. Logs: .tools/launch-board/finance-renewals-browser-final.log and finance-renewals-desktop-verified.log. The final state-preservation build passed complete workflows on desktop (21.9 seconds) and phone layout (12.8 seconds), with zero horizontal overflow and no captured browser runtime errors. Assertions verify full-width layout, summary-card order and that archive/restore preserves a renewed expiry date. Log: .tools/launch-board/finance-renewals-state-browser.log.
- Backend package and Android debug APK built successfully. The final production web build, including lint/type checks and layout CSS, passed (.tools/launch-board/finance-renewals-state-web-build.log). Existing unrelated image/hook and Android toolchain warnings are retained.

## Review findings addressed

Normal-user PUT/DELETE routes were added before generic administrator routes, with owner authorization inside the service. Live native testing caught computed response fields being round-tripped into strict write DTOs; both clients now serialize only editable fields and the native request test covers that regression. A final review exposed a stale full-record archive write that could revert a renewed date. Both clients now call a state-only endpoint, the web waits for refreshed data before closing its editor, and server/native/browser tests verify renewal-date preservation. Screenshot review caught the old Finance grid constraining the new tracker and reordering summary cards; the new layout explicitly follows the page's vertical reading order. Existing data and deployment volumes were preserved.

## Limits and acceptance

This records local engineering verification, not production-provider activation, a physical-device push test, signed mobile distribution, a capacity certification or public launch approval. Email/SMS/push need configured providers and channel/device acceptance. A provider call already in flight cannot be unsent. Receipt retention remains independent of warranty expiry. Independent launch gates remain open.

[Feature guide, API example, workflow and ER diagrams](../finance-renewals.md).

Final backend/package, native analysis/unit/widget, Android debug build, desktop/phone browser and actual native/server checks all passed after the state-only update fix. Additional final logs: .tools/launch-board/finance-renewals-state-android-final.log and finance-renewals-state-live.log.

## Final artifact and board verification

The final API JAR, assembled web bundle and Android debug APK were recorded and reverified with matching SHA-256 identities. Logs: .tools/launch-board/finance-renewals-state-artifacts-record.log and finance-renewals-state-artifacts-verify.log. Record: .tools/launch-board/build-identities-renewals-20261024.json. `releaseApproved` remains false.

Board interactions, source refresh, acceptance audit, exports/imports and 390px layouts passed with zero browser errors. The added local engineering task is M10.5: 61/90 source tasks closed; original 29 acceptance gates remain pending. Finance, API health, helper readiness and launch board all returned HTTP 200 in the final check.

[Machine-readable verification](finance-renewals-verification-2026-10-24.json).
