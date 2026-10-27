# Post options verification — 25 October 2026

Implemented the expanded Online Feed post menu in the web application and Flutter Android application with shared API persistence.

## Available actions

- Quick reactions: thumbs up, heart, laugh, surprise, sad and prayer; more emojis and custom emoji entry. Selecting the current reaction removes it.
- Post info, Reply, Copy, React, Download, Forward, Pin for me, Ask MyAaptha and Star.
- Owners retain Edit and Delete; other viewers have Report.
- Star uses the existing Saved posts functionality. Pins and stars are personal to the signed-in account.
- Reply focuses the post's comment field. Download saves the attachment or a text-only post as a text file. Forward uses the existing audience-protected sharing flow.
- Ask MyAaptha prepares an editable question without automatically submitting it. Post info shows real metadata and reaction totals; it does not invent read receipts.

## API and data

`PUT /api/social/posts/{id}/reaction` accepts an emoji or null to remove it. `PUT /api/social/posts/{id}/pin` accepts a pinned boolean. Both enforce existing post visibility and authenticated access. Legacy Like and Save actions remain compatible.

Flyway V71 adds reaction values to existing likes and a personal pin table. Repeated set requests are idempotent. Feed ordering places personal pins first and otherwise keeps newest posts first.

## Completed verification

| Area | Result |
| --- | --- |
| Backend integration tests | 5 passed: reaction replacement/removal, emoji validation, private audience enforcement, personal pin ordering, delete cleanup |
| New desktop and mobile browser scenarios | 4 passed: real menu actions, persistence, ownership and privacy rules |
| Existing compact-feed browser scenarios | Desktop and mobile passed |
| Flutter regressions | 7 passed, including 2 new post-menu widget tests |
| Static analysis and builds | Web type checking and production build passed; changed Dart files clean; API package and Android debug APK built |
| Served Android artifact | Full HTTP download SHA-256 matches the built APK; embedded post-menu code and phone API address verified |

Browser checks cover attachment download, clipboard contents, comment focus, editing, cancelled deletion, protected forwarding dialog, assistant draft without an automatic request, custom reactions, pin/star persistence, and no horizontal overflow. The menu adapts its position to available space below the fixed header.

Evidence logs are under `.tools/launch-board/post-options-*`; screenshots are `.tools/preview/post-options-desktop.png` and `.tools/preview/post-options-mobile-web.png`.

## Preview

- Web: http://localhost:3000/online-feed
- Same-Wi-Fi phone entry: http://192.168.1.5:4320/
- Android debug APK: http://192.168.1.5:4320/downloads/myaaptha-android.apk
- APK SHA-256: `6060e3f5f9329fe09261f47705e894aa1c77c72f1f835750d891667ad788b809`

The APK is a debug testing build. Physical-device installation and native file-picker acceptance have not been verified on a real phone. This enhancement does not close unrelated production release gates or change launch-board completion counts.
