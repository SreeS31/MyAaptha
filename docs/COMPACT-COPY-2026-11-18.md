# Compact workspace copy — 18 November 2026

Dashboard now keeps its five counts, a single Network heading and chart selector, and a linked Timeline heading. Removed the duplicate shortcut row, quick-action menu, decorative headings, repeated chart descriptions and empty-chart tutorials. Contact import opens from one compact control with review and consent preserved.

Removed decorative labels across authenticated pages. Shortened empty states in Interests, Finance, Health, Reports, Notifications, Contacts, diary/posts and Timeline. Financial insights are collapsed until requested. Saved text, metrics, relationship views, search, filters, primary actions, errors, privacy/consent and medical/financial scope remain available.

`backend/spring-boot-app/src/main/resources/display-copy.json` supplies generated web and native copy through `infrastructure/sync_display_copy.py`. Infrastructure CI fails if either generated client drifts. Health/Finance API disclaimers use the same resource without changing field names, response shapes or data calculations. Native empty states and contact/support copy follow the same compact approach.

Local validation: production frontend build; 23 web unit tests; 15 backend health/finance/resource tests; 110 infrastructure tests; 112 native tests passed (two opt-in integration tests skipped); Flutter analysis clean. Browser regression results and deployment evidence are recorded below after release verification.

Android debug test build: `.tools/preview/MyAaptha-beta-copy-20261118.apk`, configured for the existing HTTPS beta API. SHA-256: `1e4a6a9d114be2af00a8c1c247b922535ea2ce49a8c436f9ed9542121fc98598`. This is a test APK, not an app-store publication.

Deployed to the existing GCP beta VM on 18 November 2026: [Dashboard](https://35-244-31-192.sslip.io/dashboard). Release `beta-20261118-copy-r2`, source `d0adcffb0d96a865b437a6ce412fee9ba4835eba`.

The final review also restored one local search on Circles and Contacts and removed the duplicate Circles empty-screen action. Desktop/mobile tests verify circle filtering and that contact search reaches the API. The existing populated chart integration scenario now uses the compact copy and local search controls.

[Full CI](https://github.com/SreeS31/MyAaptha/actions/runs/44251368982) and [Beta Images](https://github.com/SreeS31/MyAaptha/actions/runs/44251375239) passed, including 44 browser checks, backend/native/infrastructure suites, production smoke validation, dependency scans and all five container security gates. Both backend and frontend deployed by immutable digest; see `infrastructure/production/copy-images-20261118.json`.

The rollout restored a fresh PostgreSQL backup into a disposable database and verified user counts before updating services. Backup: `/opt/myaaptha-beta/runtime/release-backups/20261118T063802369353Z.dump`. Schema remains V74; zero migrations applied. HTTPS/API and both container health checks passed.

Four live desktop/mobile browser scenarios passed after rollout: public page accessibility/navigation and authenticated Dashboard, Timeline, Diary, Reports, Notifications, Messages, Contacts, Circles, Career, Interests, Profile, Finance and Health. Checks covered the five dashboard counts, compact Network/Timeline panels, missing duplicate shortcuts/descriptions, local search fields, unique menu destinations, new-chat dialog, viewport bounds, browser errors, logout and the shortened Health/Finance API disclaimers.

Both exact synthetic test identities were deleted after verification; the guarded cleanup confirmed zero remaining. User data and API response fields/calculations were preserved. Native copy uses the shared resource; the Android test APK above contains the update. App-store distribution is outside this rollout.
