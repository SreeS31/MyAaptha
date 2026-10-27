# Application design and synchronization — 8 October 2026

Shared web surfaces, headings, cards, controls and spacing have been refined across the 28 application routes. Eighteen longer section introductions now use contextual “i” help; headings that already used PageHeading retain their existing help controls. Settings explanations open on demand beside their labeled switches. Empty states, errors, saved data, permissions and actionable statuses remain visible. Public landing copy remains available to explain the product.

Mobile uses the same visual palette and rounded surfaces. Shared page-header explanations, settings descriptions and storage-retention guidance now open through accessible information dialogs. The account's data and control labels remain visible.

The native Life timeline now reads profile and relationship milestones plus saved events from the same endpoints as web. Both clients use the same stable source keys, event colors and latest-first order. Add/Edit saves timeline-specific events through `/api/timeline/events`; it does not rewrite profile or relationship fields. Native supports roomy and compact spacing, information help, reload and resume refresh. Phone layouts adapt to their smaller width.

The API contract is unchanged in this update. The live native test now covers timeline save/update/list and account isolation as well as settings, storage policy, finance, circles and messages. Browser tests compare cookie and bearer sessions for the existing shared account endpoints and verify persisted timeline edits. These checks establish local compatibility for tested workflows, rather than identical feature coverage or production deployment.

Verification:

- Production web build passed: `.tools/app-design-web-build-2026-10-08.log`.
- Production browser tests: 12 passed, including accessibility and CSP checks: `.tools/app-design-web-production-e2e-2026-10-08.log`.
- Flutter analysis: no issues: `.tools/app-design-mobile-analysis-2026-10-08.log`.
- Flutter regression tests: 34 passed; one opt-in live test skipped: `.tools/app-design-mobile-tests-2026-10-08.log`.
- Actual native HTTP client test: passed against local API, including timeline persistence and isolation: `.tools/app-design-native-live-2026-10-08.log`.
- Android debug preview built: `.tools/app-design-apk-2026-10-08.log`.
- All-route audit: all 28 routes, 29 views per viewport, passed on desktop and phone widths; no horizontal overflow or detected contrast violations. Help buttons open and close with Escape. Evidence: `.tools/app-design-browser-final-2026-10-08.log` and `.tools/ui-review-current/{desktop,mobile-web}/audit.json`.
- Shared-account/profile/timeline browser checks: all six distinct cases verified across the main run (four passed) and the corrected account-selector rerun (two passed). Evidence: `.tools/app-design-account-final-2026-10-08.log`. The initial account checks used a broad label lookup that also matched the new help button; the final checks select the checkbox by its exact accessible role.

The preview startup now records each owned process before its readiness wait, so a partial startup can be stopped safely. Preview database content is preserved.

Local preview: `http://localhost:3000`. Updated Android preview: `mobile/flutter-app/build/app/outputs/flutter-apk/app-debug.apk`. Installed applications require the updated package; physical-device/iOS testing and production rollout are outside this local verification.
