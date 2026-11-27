# Dashboard, finder and automatic circles

Dashboard metric cards link to relationships, circles, managed profiles, unread messages and notifications, including zero counts. Network chart values and circle ownership totals also link to their destinations. Mobile dashboard cards provide corresponding navigation.

The top field is now **Find people & Circles**. It combines current-page matches with accessible people and circle results, with a link to the complete search page. Duplicate sidebar search entries and the repeated dashboard search disclosure are removed. Mobile uses the same label and combined search.

Automatic private-contact grouping requires at least three distinct saved contact records. Suggestions accumulate across import batches until that threshold is met. Imported contacts are not invited to conversations. Manual circle creation and explicit assignment remain available at any size. The legacy AI organizer also requires three distinct confirmed people before creating a suggested circle.

Migration V82 preserves pending source labels and removes only untouched legacy automatic circles with fewer than three private contacts. It preserves manual circles, circles with other members/admins, messages, posts, calls, activities or chat settings, and all private contacts. Explicit circle edits mark the circle as manually maintained.

Local validation: automatic-circle/address-book tests (9), AI organizer tests (2), mobile navigation/finder tests (6), clean Flutter analysis, and a successful web production build. All 14 targeted desktop/mobile browser checks passed sequentially. The parallel local browser run encountered Chromium session timeouts; the sequential run passed without application changes. One new search fixture was corrected to include the API-required circle owner name.

GCP deployment remains pending the existing antivirus freshness gate. No scanner security policy is changed by this release. Automatic approval review rejected the earlier proposed 48-to-72-hour relaxation because explicit approval for that setting was absent.

Published application source: `12aba3d896b2bc15a4b769d7426f67770a4f7e6a`, tag `beta-20261127-dashboard-finder-r1`. [Full CI](https://github.com/SreeS31/MyAaptha/actions/runs/46034838276) and [validated beta images](https://github.com/SreeS31/MyAaptha/actions/runs/46034839425) passed, including PostgreSQL/Redis production smoke checks. Results: backend 328 tests (one skipped), browser 110 passed, web unit 30 passed, native 144 passed (two skipped), and clean native analysis. Immutable image references are in `infrastructure/production/dashboard-finder-images-20261127.json`.

A normal scanner update check still reports ClamAV definitions 28194, built 25 November 2026 06:26:59 UTC, as the latest available. Existing backend readiness remains UP; the overall health freshness requirement remains unsatisfied. The previous application images remain live and migration V82 has not been applied to GCP.

The Android debug beta APK is built at `.tools/preview/MyAaptha-beta-dashboard-finder-20261127.apk`, targeting the existing beta API. Its SHA-256 is recorded in the image manifest. This is a test build; store publication and physical-device acceptance are separate pending tasks.
