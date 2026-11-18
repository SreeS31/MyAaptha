# Compact workspace copy — 18 November 2026

Dashboard now keeps its five counts, a single Network heading and chart selector, and a linked Timeline heading. Removed the duplicate shortcut row, quick-action menu, decorative headings, repeated chart descriptions and empty-chart tutorials. Contact import opens from one compact control with review and consent preserved.

Removed decorative labels across authenticated pages. Shortened empty states in Interests, Finance, Health, Reports, Notifications, Contacts, diary/posts and Timeline. Financial insights are collapsed until requested. Saved text, metrics, relationship views, search, filters, primary actions, errors, privacy/consent and medical/financial scope remain available.

`backend/spring-boot-app/src/main/resources/display-copy.json` supplies generated web and native copy through `infrastructure/sync_display_copy.py`. Infrastructure CI fails if either generated client drifts. Health/Finance API disclaimers use the same resource without changing field names, response shapes or data calculations. Native empty states and contact/support copy follow the same compact approach.

Local validation: production frontend build; 23 web unit tests; 15 backend health/finance/resource tests; 110 infrastructure tests; 112 native tests passed (two opt-in integration tests skipped); Flutter analysis clean. Browser regression results and deployment evidence are recorded below after release verification.

Android debug test build: `.tools/preview/MyAaptha-beta-copy-20261118.apk`, configured for the existing HTTPS beta API. SHA-256: `1e4a6a9d114be2af00a8c1c247b922535ea2ce49a8c436f9ed9542121fc98598`. This is a test APK, not an app-store publication.

Deployment: pending validation and image gates. This release has no database migration.
