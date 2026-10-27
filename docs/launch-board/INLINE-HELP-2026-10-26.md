# Compact inline guidance — 26 October 2026

## Changes

- Grouped 26 web heading/help pairs into shared inline layouts. This covers account controls, search, contacts, discovery, feed composition, finance, moderation, notifications, privacy, profile editing, reports, settings, trust and timeline sections.
- Converted the separate relationship-chain, family-tree and relationship-form Help rows into small information controls. Form guidance sits beside Person type; broadcast guidance sits beside Message your tree. Full explanations remain available on demand.
- Merged security-report guidance into its existing heading information control. Assistant privacy guidance now follows the short processing message. Upload-level guidance has an inline heading.
- Shared information buttons use compact visual sizing with larger coarse-pointer targets, keyboard access, Escape dismissal and outside-click dismissal. Panels retain viewport-aware positioning.
- Added a small renewal-expiry distribution bar with visible counts and a complete text alternative. It uses current, unarchived records, distinguishes expired / due soon / later, and is hidden when there are no current records.
- Native Flutter uses a shared inline label/help layout in page headers and settings. Timeline editing guidance sits in the dialog title. Storage uses a smaller ring with usage totals beside it and the per-file limit below.

## Verification scope

Native inline guidance is tested at normal and 170% text scale, including opening and dismissing its full explanation. Native profile and workspace navigation regressions are included. Browser verification checks heading alignment, complete information access, viewport bounds, renewal chart data and existing workspace/form behavior on desktop and phone layouts.

Build/test logs: `.tools/launch-board/inline-help-*20261026.log`. This is a UI enhancement; production launch gates and physical-device acceptance remain separate.

## Recorded checks

- Eight reviewed desktop/mobile browser scenarios passed: populated route sweep, inline guidance, tree depth behavior and renewal data/receipt synchronization. The route sweep waits for visible loading messages to clear; 28 routes per layout had no horizontal overflow.
- Expanded form audit: 27 views per desktop/mobile layout, zero violations for the selected contrast, label and control-name rules. Workspace keyboard navigation and messaging regressions also passed in the broader run.
- Seven native widget/regression tests passed. Changed native files passed static analysis. Android debug APK built and its complete HTTP download matched the recorded SHA-256; its phone API address and inline-help code were verified in the artifact.
- The broad first run retained diagnostic failures from an overly strict baseline assertion and a browser network-change interruption. Its results are not represented as a fully passing suite. The reviewed run passed eight scenarios.

The final visual review found an older tree CSS rule forcing broadcast guidance below its action bar. Its specificity was corrected and a dedicated same-row assertion was added; see the final focused verification log for that correction.

Android testing download: http://192.168.1.5:4320/downloads/myaaptha-android.apk (same Wi-Fi). SHA-256: `99313bea6882aa33a82991f2cc98539ed2a762d72c3805f9f14c62fcd7dd7309`. Reinstall this debug build to see the native changes. Physical-phone acceptance remains pending.

Final focused verification: two desktop/mobile scenarios passed after the broadcast-row specificity fix, including same-row positioning, full guidance, form open/close, six page-header checks and viewport-safe popovers. Log: `.tools/launch-board/inline-help-final-focused-20261026.log`. Final production build passed; its static error-page generation retried successfully before completion.
