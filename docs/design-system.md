# MyAaptha interface standard

Web and Flutter use the same bundled Roboto regular and medium font files. Font licences are included beside the assets. Fonts do not depend on a third-party font request.

| Element | Size | Weight |
| --- | --- | --- |
| Page heading | 24 | Medium |
| Section heading | 20 | Medium |
| Card heading | 18 | Medium |
| Body, labels, navigation, controls, metadata | 14 | Regular or medium |

Primary colour: #256F7B. Heading: #15233B. Body: #35445D. Secondary text: #59697D. Border: #D9E2EA. Surface: white. Page background: #F4F7FA. Semantic error, warning and success colours remain distinct.

Desktop buttons use 34-pixel minimum height and 16-pixel corners. Touch controls retain 44-pixel minimum targets. Fields use 36-pixel minimum height with consistent focus styling. Cards use 12-pixel corners. Web app-bar icon controls have a compact 40-pixel minimum. Native sizes are logical pixels and retain platform accessibility scaling.

Web tokens and common rules live in `frontend/nextjs-app/app/design-system.css`, imported after the existing global styles. Native tokens and component themes live in `mobile/flutter-app/lib/core/theme/app_theme.dart`. New screens must reuse these definitions rather than introduce new font sizes, fonts or brand colours. API responses supply data, not client visual styles.

Message actions use a two-column action grid, a separate reaction row, clear selected states and expandable delivery/read information. Private stars and pins retain their existing behaviour.

## Verification

`integration/design-system.spec.ts` checks public, signed-in member and administrator routes on desktop and phone-sized Chromium. It verifies loaded fonts, control and heading sizes, horizontal overflow and automated text contrast, and saves full-page screenshots and JSON audit records under `.tools/ui-review`.

The integration fixture promotes only its own freshly created test account for administrator checks, then restores that account to USER. Run only against the local preview database. It is not a production test runner.

The messaging browser integration exercises the redesigned controls. Flutter messaging widget tests use the real application theme, including a narrow phone viewport for forwarding. Physical Android/iOS review remains separate from widget and browser tests.

## Local verification on 26 September 2026

- Production web build passed; existing image-optimization lint warnings remain.
- Web unit tests: 11 passed. Public-page browser tests: 8 passed.
- Route audit: 26 route views each on desktop and phone widths passed, including member and administrator dashboards. No automated text-contrast failures or page-level horizontal overflow in these views.
- Messaging integration: desktop and phone flows passed for private stars/pins, read receipts, archive/mute/unread settings and forwarding.
- Flutter analysis: no issues. Flutter tests: 24 passed, including the real-theme narrow chat view.
- Android release compilation passed. A deployable release must be rebuilt with a real HTTPS `API_BASE_URL`; the default release artifact is not configured for sign-in. Use the debug APK for local Android emulator testing (host API at `http://10.0.2.2:8080`).

These checks do not certify every populated state, physical device, iOS build, WhatsApp feature parity or production capacity for 300,000 accounts. This change addresses interface consistency; those broader readiness requirements remain separate.

Local Android debug APK: `mobile/flutter-app/build/app/outputs/flutter-apk/app-debug.apk` (build passed). The default local address is for an Android emulator on this computer; physical phones need a reachable API address configured at build time.

## Compact pastel revision (27 September 2026)

The compact layout uses sky, lavender, mint, peach and rose fills with dark foregrounds. The top search filters contacts or circles on those pages; elsewhere it opens global search. Circle-message search is an expandable scoped filter. Duplicate diary actions, search navigation shortcuts and notification shortcuts were removed from the web shell. Notifications are available inside Personal settings.

`InfoTip` supports pointer hover, keyboard focus, click/tap to keep information open, and Escape/blur dismissal. Optional explanatory copy is collapsed; consent checkboxes, errors and status messages stay visible. Circle ownership, posting permissions and the current user's role are in Circle details.

The dashboard chart switches between saved relationship types and circle membership. Finance compares income with spending; values come from the selected month's API response. No sample data is displayed to users. Chart rows retain visible labels and numeric values.

### Compact revision verification

Final production web build passed. The route audit passed 26 views on each of desktop and phone-sized Chromium, using document client width to detect overflow. No automated contrast failures were found in these views. Both interaction tests passed for top-bar circle/contact search, collapsed circle details, notification settings navigation, info-popup Escape dismissal and actual viewport bounds, and financial chart values/proportions. Desktop and phone messaging tests also passed. Web unit tests: 11 passed; public-page browser tests: 8 passed. Flutter analysis reported no issues, all 24 tests passed, and the Android debug APK rebuilt successfully.

Screenshots: `.tools/ui-review/` and `.tools/pastel-review/`. Current app: `http://localhost:3000`. These are local browser/widget checks, not physical-device or production-capacity certification.
