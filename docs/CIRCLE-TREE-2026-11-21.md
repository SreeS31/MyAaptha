# Circle tree restoration - 21 November 2026

My circles now opens an expandable tree: You -> circles -> members and private contacts. It no longer mounts the chat workspace. The separate Messages link opens `/messages?circle=ID`. Circle creation, local name/member search, collapse controls and links to manage private contacts remain available. The mobile circle screen also expands people beneath circle branches and opens conversations only through its Messages action.

Private contacts remain separate from messaging members. Only the existing authenticated address-book API supplies private contacts, loaded on demand with cursor pagination. No contact import or tree expansion adds messaging membership. The existing network/address-book APIs are unchanged; no database migration was required, and schema remains V74.

Published source: `1c6dbeb280bd5d335038b81dfa95a3b6d60a808a`, tag `beta-20261121-circle-tree-r2`. [CI](https://github.com/SreeS31/MyAaptha/actions/runs/44891224386) and [image validation](https://github.com/SreeS31/MyAaptha/actions/runs/44891224727) passed. Immutable image references and rollback references are recorded in `infrastructure/production/circle-tree-images-20261121.json`.

Validation:

- CI: 58 desktop/mobile browser checks, 26 web unit tests, backend/native checks, production smoke checks and security scans passed.
- Local: production build and type checks passed; Flutter analysis was clean; 117 native tests passed with two expected opt-in integration skips. Focused tree checks passed accessibility, viewport fit, member search, collapse, private-contact pagination and explicit messaging navigation.
- The provider-cancellation browser fixture now waits for the synthetic provider document before closing the popup, avoiding Chromium target-swap races. Ten repeated desktop/mobile production-browser cases passed; this changes the fixture only.
- Live: four desktop/mobile scenarios passed, covering circle creation, expansion, private-contact leaves, message deep links, public-page accessibility, viewport fit and absence of browser errors. Google contact configuration remained active after rollout. No external mailbox authorization was performed by these tests.
- A fresh PostgreSQL backup was restored into a disposable database and its user count verified before rollout. Backend/frontend health and exact running image references passed.
- Both synthetic test accounts and all their owned contacts/circles were removed. Post-cleanup SQL counts are zero.

Android debug test APK: `.tools/preview/MyAaptha-beta-circle-tree-20261121.apk`; SHA-256 `f00e77a0f143e0bd9f736fa5f948e1fad70f68a040803a5add573133cfa9ffb2`. It uses the existing HTTPS beta API and is not an app-store release.
