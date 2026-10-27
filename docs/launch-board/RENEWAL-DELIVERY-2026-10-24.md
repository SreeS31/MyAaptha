# Renewal delivery hardening - 24 October 2026

A provider retry or quiet-hours deferral could previously deliver an outdated countdown while the warranty remained active. Delivery now requires the exact original 30/15/7/3/1-day milestone date in the saved time zone. At local midnight the stale message becomes ineligible. In-app history is retained; renew, pause, archive and delete invalidation remains enforced.

Ten focused backend tests passed: eight service tests and two controller tests, with zero failures, errors or skips. New coverage verifies the last second before midnight and midnight itself for all five milestones, plus expiry-day suppression. Existing owner isolation, renewal-cycle cancellation, date scheduling and state-only updates passed.

Evidence: `.tools/launch-board/renewal-stale-delivery-tests.log` and Surefire reports. Tests use the local H2 fixture; no external recipients or paid providers were contacted. This is local engineering evidence for M13.3, not provider delivery acceptance.

Production preflight still reports missing release configuration, five protected secret files and the database CA. The project owner supplies environment/account references and business decisions; engineering performs setup and testing once those inputs exist. See [owner inputs](LAUNCH-INPUTS-2026-10-22.md).

Launch totals remain 61/90 complete, 29 pending.

The backend package was installed in the preserved local preview. Finance, API health, helper readiness and the launch board returned HTTP 200. Updated API/web/debug-APK artifact identities verified successfully; releaseApproved remains false. The refreshed board passed all interaction checks with zero browser errors.
