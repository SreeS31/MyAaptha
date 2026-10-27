# Timeline event editing — 8 October 2026

The web timeline offers Add event, an Edit event control on every milestone, top-right type tags, and Wave/Compact view controls above the events. Both views keep the latest events first. Compact view reduces spacing and uses one column. The narrower phone layout keeps cards readable beside the wave.

New events and edits are stored privately through `GET /api/timeline/events` and `PUT /api/timeline/events/{key}`. Migration V68 adds an account-scoped table. The API validates event type, title and date, and limits each account to 500 saved entries. Users cannot read or modify another account's events through these endpoints.

**17 October update:** web and native now support confirmed deletion of saved custom events and reset of saved overrides through owner-scoped `DELETE /api/timeline/events/{key}`. Source profile/relationship milestones remain intact. See [implementation and current checks](launch-board/DEVELOPMENT-2026-10-17.md).

Existing profile/relationship milestones have stable keys. Editing one saves a timeline-specific override; it does not change the original profile or relationship fields. The editor explains that distinction. A new event has its own key and persists across reloads. The later [application design update](app-design-2026-10-08.md) also aligns the native timeline with these milestones and event endpoints.

Evidence: `.tools/timeline-editor-api-tests-2026-10-08.log`, `.tools/timeline-editor-api-package-2026-10-08.log`, `.tools/timeline-editor-web-build-2026-10-08.log` and `.tools/timeline-editor-browser-final-2026-10-08.log`. The API test passed persistence, update, date validation and account-isolation assertions. Both desktop and phone browser cases passed event creation/editing, persistence after reload, view switching and overflow checks. The API package and production web build passed. Compact screenshots are in `.tools/preview/timeline-compact-desktop.png` and `.tools/preview/timeline-compact-mobile-web.png`.
