# Pending work follow-up — 25 October 2026

Continued the locally executable parts of the account, messaging, finance and operations launch tasks. External launch acceptance remains separate from local verification.

## Findings and changes

- Account synchronization and UTC finance month-boundary scenarios passed on desktop and mobile web (four browser scenarios). Browser cookies and mobile-style bearer requests share account data; finance transactions at month boundaries belong to exactly one UTC month.
- The messaging regression initially referenced the old “Circles” filter label. Updated it to “Groups & circles” to match the reorganized navigation.
- Continuing past that selector exposed a desktop layout defect: the section-navigation bar consumed space above a chat pane sized to the full remaining viewport, pushing the composer below the screen. The messaging content container now reserves the section-navigation height with a bounded flex layout. The regression requires the entire message text field to be in view.
- A cold-start run exposed a sign-in hydration race: submitting the server-rendered form before client handlers were attached could return to `/auth` without signing in. Sign-in and registration fields are now disabled until the client is ready, and while submitting. A delayed-JavaScript browser scenario verifies this readiness boundary.
- Forwarding regression now awaits the actual forwarding HTTP response and checks its status before expecting the picker to close, rather than treating a response slower than five seconds as a functional failure.
- Release-rendering, prerequisite and artifact tooling: 21 automated tests passed. Scanner tooling: four passed. Storage-recovery tooling: ten passed. These are tool contract tests, not live production scanner or storage-recovery acceptance.

## Infrastructure prerequisites checked

The read-only release prerequisite check found the release JSON, five protected secret files and database CA missing or invalid at the documented production paths. It printed check identifiers only and contacted no external services. Existing local preview credentials are not production configuration. This check does not establish whether accounts exist elsewhere.

Provide hosting/project, domain, budget and protected configuration references using [the dependency reply file](MYAAPTHA-DEPENDENCIES-TO-FILL-2026-10-25.txt). Engineering retains configuration, integration, testing and remediation work; routine local development does not require additional confirmation.

Evidence: `.tools/launch-board/pending-regression-20261025.log`, `pending-preflight-20261025.json`, `pending-composer-build-20261025.log`, `pending-auth-build-20261025.log` and the final reviewed browser log. The initial regression log records four passes and the two old-label failures; it must not be described as a completely passing run.

No launch gate is closed by this report. The tracked total remains 61 of 90 complete, with 29 awaiting launch acceptance.

## Final reviewed result

All eight current-build browser scenarios passed (four desktop and four mobile web): account synchronization, delayed-JavaScript sign-in readiness, UTC finance boundaries, and mixed forwarding/circle messaging. The messaging scenario confirms all of the composer is visible, ten-recipient forwarding succeeds, message information opens, Star persists and the page does not overflow horizontally. Production frontend build passed.

Final log: `.tools/launch-board/pending-reviewed-browser-20261025.log` (8 passed, 2.4 minutes). Earlier failure logs are retained as diagnostic history and are superseded for these scenarios by this reviewed run. Preview restarted successfully with these fixes at http://localhost:3000. Physical-device and selected-staging acceptance remain open.
