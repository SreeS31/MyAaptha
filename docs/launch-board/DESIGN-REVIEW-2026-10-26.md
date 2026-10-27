# MyAaptha interface review — 26–27 October 2026

The review covers shared web/native presentation and the account APIs used by those interfaces. It does not replace physical-device, production-provider or independent release acceptance.

## Changes

| Area | Result |
|---|---|
| Launch board | Opens with current source evidence, even when this browser has an older saved plan. The status-source selector loads saved edits explicitly; switching back preserves them. Current totals appear before collapsible engineering detail. Mobile columns stack vertically. Tabs support arrow/Home/End keys; phase headers, count badges and muted text have stronger contrast. |
| Settings | Save action stays in document flow on phones, so it cannot cover preference controls. Short status copy keeps explanatory text in an inline information control. Section links have distinct borders; narrow quiet-hour fields stack. |
| Web typography | Existing locally bundled Roboto remains consistent. Shared body/heading tokens use relative sizes and respect the browser default font setting. Decorative labels are smaller; navigation and primary content stay readable. |
| Navigation icons | Shared vector icons replace device-dependent text symbols in the menu, search and quick tools. Mobile quick tools have short visible labels. Menu structure and destinations are preserved. |
| Shared web controls | Long labels and values wrap, anchor/form controls have header clearance, selected section tabs have an underline, and forced-colour selected controls gain an outline. |
| Information controls | An open panel can receive keyboard focus for reading/scrolling. Escape closes it and returns focus to its trigger. Full help content remains available. |
| Native theme | Consistent card/control corners, quieter app bar/drawer colours, clearer caption/label hierarchy and explicit error colour. Inputs allow multi-line help/errors. Bottom navigation is more compact while primary action buttons retain at least 44px. |
| Static brand logo | Auth/header use an existing precomputed 256px WebP (15,834 bytes). The full-resolution original is preserved. This removes cold-start logo optimization from the sign-in path. |
| Native regression test | Updated the outdated chat test label to the current “Groups & circles”; archive, mute, unread and group filtering remain exercised. |

The API contract is unchanged by these visual fixes. Settings, renewals, privacy and call configuration are covered by backend regression tests; the live cookie/bearer suite checks shared account responses and persisted updates. Local synthetic tests do not establish real notification or call-relay delivery.

## Evidence

The final check totals, limitations and build references are recorded in [design-review-verification-2026-10-26.json](design-review-verification-2026-10-26.json). The new narrow-screen review uses 320px width and 125% browser root text. Native settings are checked at 320px with 100% and 200% text scaling. Expanded forms are checked separately from page overviews.

## Local preview reliability

Windows reserved TCP 56379 after an idle period, preventing Redis from binding and blocking the preview restart. The development Compose default now uses loopback port 16379, outside the dynamic range; `start-local.ps1 -RedisPort <port>` configures both Compose and Spring consistently. Production manifests are unchanged. Database/media volumes are preserved. Compose mapping and a successful preview restart verify the correction.

## Remaining launch requirements

The [remaining input file](MYAAPTHA-REMAINING-INPUTS-2026-10-26.txt) requests actual access and resources. Received company/role, domain, region and budget answers are now distinguished from missing access in the board's requirement descriptions. Visual improvements do not close external production, provider, physical-device or independent-review gates.

## Completed verification

45 distinct automated scenarios passed: 14 browser, 9 native and 22 backend. The browser scope includes 28 routes and 27 expanded form states per layout, 16 cookie/bearer account endpoints, cold static-logo loading, 320px reflow, enlarged text and keyboard information panels. Board tests cover source selection, preserved saved plans, keyboard tabs and selected contrast/label rules.

The last app run passed 11 scenarios and hit one five-second sign-in navigation wait after successful authentication. That desktop scenario passed a focused rerun with a bounded 15-second navigation wait; its functional assertions were retained. This is not production capacity acceptance.

Backend, production web and Android debug builds passed. Build identities are recorded in the verification JSON. No new launch tasks were added: the current scope stays 61 complete / 90 total, with 29 external release gates open.

## Review images

[Launch board](design-review-2026-10-27/launch-board.png) | [Desktop workspace](design-review-2026-10-27/desktop-dashboard.png) | [Mobile settings](design-review-2026-10-27/mobile-settings.png)

## Current mobile preview

The computer Wi-Fi address changed from 192.168.1.5 to 192.168.1.4 during this review. The bridge and rebuilt debug APK now use `http://192.168.1.4:4320`. Bridge health, anonymous rejection and six authenticated endpoints passed. The complete APK download returned 200 and its SHA256 matches the build. A new guard returns 503 while the APK identity points to a different network address or publication is incomplete. Firewall rules were unchanged; physical-device acceptance remains open.

[Download the current Android test APK](http://192.168.1.4:4320/downloads/myaaptha-android.apk) on the same Wi-Fi.
