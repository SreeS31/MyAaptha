# Navigation reorganization - 24 October 2026

## Implementation

Nine matching main categories replace the previous long web sidebar and Flutter drawer/desktop rail: Dashboard, Relationships, Diary & Memories, Health, Finance, Career, Interests, Messages and Online Feed. Dashboard contains timeline/profile/trust tabs; Messages contains the inbox, circle management, contacts and discovery; Online Feed contains shared updates/stories and following/followers. Account, support and safety tools remain available separately.

All 19 old web menu URLs are retained and mapped in a temporary comparison view at `/menu-comparison`; Flutter exposes Menu comparison in its drawer and account tools. This is a review surface, not a second data store or permission switch. Web-only administrator security/error tools are explicitly identified in the native comparison.

Career and Interests reuse the existing profile API and section-preserving save behavior. The previously unexposed hobbies field is now editable on both clients and visible in the full profile. Scoped views omit unrelated profile-media and account controls. Notification links continue to open shared social posts. Native Messages unread badges include both direct and circle conversations.

## Verification

Final logs are under `.tools/launch-board/navigation-*`. Native widget checks exercise lazy tab loading, draft preservation, comparison destination callbacks and preserving a concurrently updated employer when saving hobbies, plus existing profile and finance regressions. Browser checks exercise all previous destination links, the nine primary entries, Dashboard and Messages tabs, Career/Interests persistence through the real profile API, social audience controls, account tools and viewport width.

The change does not close production-provider, physical-device, store-signing or independent release gates. Launch task scope remains 90; the navigation work improves existing web/native modules.

See [navigation guide](../navigation-reorganization.md).

An initial browser run passed both navigation scenarios and the desktop profile regression. The phone profile regression was interrupted by a local preview restart while creating its synthetic account (ECONNRESET); it requires rerunning against the final preview. This interrupted attempt is not counted as a passing check.

Final reviewed web verification: production build passed; all four desktop/phone navigation and profile scenarios passed (1.5 minutes reported by the test runner). The interrupted phone regression passed on rerun. Desktop and phone viewport screenshots were inspected after correcting heading spacing; tested pages reported no horizontal overflow or browser page errors. Evidence: `navigation-web-build-reviewed.log`, `navigation-browser-reviewed.log`, and `.tools/preview/navigation-*-viewport.png`.

Final native verification: clean analysis, eight passing widget/regression tests and successful Android debug APK assembly. The additional scoped-profile regression verifies saved-data refresh after another section changes the profile, keeps an open draft intact and reloads latest saved values on cancel. Evidence: `navigation-native-analysis-sync.log`, `navigation-native-tests-sync.log`, `navigation-native-build-sync.log`. Finance, comparison, API health and launch-board endpoints returned HTTP 200 after installation.

Final API, assembled standalone web and Android debug APK identities were recorded and verified successfully (`allPresent=true`, `matches=true`, `releaseApproved=false`) and frozen in `.tools/launch-board/build-identities-navigation-20261024.json`. Launch totals remain 61/90 complete and 29 pending; this navigation update does not alter the remaining external release gates.
