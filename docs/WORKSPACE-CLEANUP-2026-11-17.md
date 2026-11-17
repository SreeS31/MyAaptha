# Workspace navigation cleanup - 17 November 2026

The main menu is now the navigation surface on desktop and its drawer on phones. Removed the repeated top section menus, global search field and right-side tools rail. Page searches, filters, primary actions, help, security controls and all feature destinations remain available.

Messages has one local search, its existing folder filters, one new-chat action and conversation settings. The duplicate empty-state new-chat button and promotional heading were removed. Secondary destinations (circles, contacts, timeline, profile and trust) now appear once in the main menu. Notifications, help and account controls are in that menu too. The retired menu-comparison page redirects to Dashboard.

Shared page headings no longer need separate decorative panels. Removed redundant finance metadata and Interests promotional text, and the Reports cross-page menu. Medical/financial notices and labels that explain user decisions remain intact. Useful in-page controls such as transaction filters and settings-section anchors are retained.

Native navigation follows the same approach: drawer/rail destinations replace top-level section chips, bottom shortcuts and the second tools rail. Messages receipt settings are collapsed until needed. Dashboard shows relationship counts by type rather than another set of navigation cards. Visited screens retain their state.

Native Interests now uses the same `/api/interests` endpoints as web for saved hobbies, groups, area/topic discovery, membership requests/approval, editing, member-only discussions and leaving. The catalogue is generated from the web source (410 interests); an infrastructure test fails if the native catalogue drifts. Both profile editors use the picker and update only hobbies. There are no selection/group count quotas. The native editor owns its controllers through its dialog lifecycle, including closing animations and large-text layouts.

No backend API or schema changes are required for this cleanup. The existing deployed V74 backend supports both clients. Browser tests use fixtures for interactions; live synthetic acceptance is a separately opted-in check after rollout. Android test builds use `API_BASE_URL=https://35-244-31-192.sslip.io`; debug APKs are test artifacts, not signed store releases.

## Verification scope

- Production web build: passed before final tests; existing image-optimization lint warnings remain.
- Focused web checks: desktop/mobile single-search behavior, new-chat access, accessibility, destination uniqueness and navigation passed.
- Native focused checks: shared API paths/verbs/authentication/pagination, group approval and discussion privacy, hobbies/profile preservation, picker selections and 320px/200% text group editing passed.
- Infrastructure: 109 checks passed, including native/web catalogue parity.
- Full production browser suite: 38 checks passed, including the 29-route audit on phone/desktop layouts. Web type checking and 23 unit checks passed.
- Final native analysis: no issues. Full native suite: 112 tests passed, two existing live-integration skips. The additional large-text/editor lifecycle regression is included.
- Android debug test APK built successfully with the same beta HTTPS API URL. Local artifact: `.tools/preview/MyAaptha-beta-workspace-20261117.apk`; SHA-256: `18e2c6ff71bb7ec519c47498d5ee682ec5d5ed4b15e32d6570751277da034f3c`.
- The APK is a test build, not an app-store release. Physical Android/iOS device acceptance and store signing/distribution are separate from the widget/API and build checks.
- Cloud validation and deployment evidence are recorded below after rollout.

The browser fallback/layout audit checks the following 29 routes at phone and desktop widths, including font consistency, viewport bounds, one visible main region, accessible drawer navigation, and absence of the removed shell controls. These fallback checks deliberately abort API calls; they are separate from successful-data workflow tests.

- `/dashboard`
- `/relationship-tree`
- `/feed`
- `/health`
- `/finance`
- `/career`
- `/interests`
- `/messages`
- `/online-feed`
- `/profile`
- `/timeline`
- `/circles`
- `/contacts`
- `/settings`
- `/trust`
- `/help`
- `/notifications`
- `/reports`
- `/privacy`
- `/ai-activity`
- `/security-reports`
- `/discover`
- `/following`
- `/followers`
- `/posts`
- `/circle-search`
- `/menu-comparison`
- `/workspace-tools`
- `/people/1`
