# Profile and storage design update — 7 October 2026

The web and Flutter profile screens now show saved account details by default. Edit opens one section; Cancel discards its draft; Save returns to the overview after the API confirms the update. Both clients show the same personal, address, communication, education and employment fields. The account phone number remains read-only. A profile identity card and image fallback improve the overview.

Both clients read storage usage and limits from `/api/uploads/policy`. The circular meter shows percentage and used GB in its center, with total storage, available storage and the per-file limit below or beside it. The ring is bounded at 100% while the displayed percentage can report usage exceeding a reduced quota. A zero capacity produces a zero meter rather than invalid numeric values. Administrator controls and API enforcement continue to apply.

**17 October update:** native profile-photo upload/change/removal and gallery add/removal now use the existing shared profile-media API, with size/type checks, busy/error states and confirmation. Actual native upload/removal checks passed; physical-device acceptance remains separate. See [development results](launch-board/DEVELOPMENT-2026-10-17.md).

Profile saving fetches current API data and merges only the edited section, preserving changes made to other sections while the form is open. This does not provide atomic conflict resolution for simultaneous saves to the same section. Web refreshes saved profile/storage data on focus/reconnection; native refreshes on resume without replacing an active profile draft.

Verification evidence:

- Production web build: `.tools/profile-storage-web-build-2026-10-07.log`.
- Desktop and mobile browser checks: `.tools/profile-storage-browser-2026-10-07.log` (two cases passed). Includes default read-only display, edit/cancel/save, API response agreement, another client's change preserved during editing, focus refresh, actual storage-policy values, a simulated 50% meter and horizontal overflow checks.
- Flutter analysis: `.tools/profile-storage-mobile-analysis-2026-10-07.log` (no issues).
- Targeted native tests: `.tools/profile-storage-mobile-tests-2026-10-07.log` (four passed), including profile draft cancellation, section preservation, usage refresh and administrator validation.
- Complete Flutter suite: `.tools/profile-storage-all-mobile-tests-2026-10-07.log` (32 passed; one opt-in live test skipped).
- Android preview build: `.tools/profile-storage-apk-2026-10-07.log` (built successfully).
- Screenshots: `.tools/preview/profile-overview-desktop.png`, `.tools/preview/profile-overview-mobile-web.png`, `.tools/preview/storage-ring-desktop.png` and `.tools/preview/storage-ring-mobile-web.png`. Storage screenshots use a simulated 50% response; actual account usage is unchanged.

The local preview runs at `http://localhost:3000`. The Android preview is at `mobile/flutter-app/build/app/outputs/flutter-apk/app-debug.apk`. Production deployment and updating installed apps are separate rollout steps.
