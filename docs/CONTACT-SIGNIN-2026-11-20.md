# Simple contact sign-in — 20 November 2026

MyAaptha members now choose **Sign in with Google** or **Sign in with Microsoft**, select an account on the provider's page, approve read-only access when needed, and review contacts/circles before saving. Members never register OAuth clients, handle JSON files or enter application credentials.

Removed mandatory email-entry forms from Contacts and the older contact organizer on web/mobile. Email hints remain optional in the API for existing clients. The provider account chooser handles account selection; Google is no longer forced to repeat its consent screen on every import. State, PKCE, read-only scopes, ownership checks, temporary result storage and explicit saving consent remain in place.

Provider sign-in starts directly from its button. Saving consent and circle selections appear with the contact preview. File/device import remains available under **Other ways to import**. Unavailable service messages are written for members and do not ask them to configure credentials. No contacts are saved by signing in alone.

The Google/Microsoft OAuth application is still a **one-time MyAaptha owner/deployment configuration** shared by all members. Current beta provider credentials remain absent. This release changes the member experience; it does not fabricate provider credentials or claim an actual mailbox authorization. Activation tooling and the owner-only setup guide already exist in the repository.

Deployed to the existing GCP beta VM on 20 November 2026 using scanned immutable backend/frontend images from commit `b18acea91e0952d059b2086b4d06a9d0d0d7e59b`, tag `beta-20261120-contact-signin-r2`. [CI](https://github.com/SreeS31/MyAaptha/actions/runs/44709280744) and [image validation](https://github.com/SreeS31/MyAaptha/actions/runs/44709280829) passed, including production smoke checks and container security scans. No database migration was required; schema remains V74. Image digests and deployment evidence are recorded in `infrastructure/production/contact-signin-images-20261120.json`.

Validation: 55 browser tests and 26 web unit tests passed in CI. Local checks also passed: production build, 14 focused production popup/security cases, 116 native tests (two expected live integration skips), clean Flutter analysis, and 18 targeted backend OAuth/address-book cases. The account-chooser assertions were repeated after removing forced repeat consent. The browser fixtures simulate an external provider and do not constitute a real mailbox authorization.

Android debug test build: `.tools/preview/MyAaptha-beta-contact-signin-20261120.apk`; SHA-256 `f2c56f4997f38df0a05e3079f0df8c97156d7afec06877561b15c3fadeeaa399`. This is a test APK, not an app-store publication.

The Contacts/Dashboard OAuth entry pages and the two provider callbacks use `same-origin-allow-popups`, as recommended by [Google](https://developers.google.com/identity/oauth2/web/guides/get-google-api-clientid). Other pages retain `same-origin`; CSP, nonce, frame and transport protections are unchanged. Cross-origin browser fixtures cover successful preview, actual window cancellation and blocked popups.

Live verification: all four desktop/mobile scenarios passed, covering provider entry buttons without manual email, scoped popup headers, unavailable-provider feedback, preview of three synthetic email-only contacts, editable circle suggestions, explicit save consent, duplicate-safe imports, circle messaging wording, viewport fit and public-page accessibility. The two synthetic accounts and all their owned contacts/circles were removed; post-cleanup SQL counts are zero. A fresh backup was restored into a disposable database and its user count verified before rollout. Backend/frontend health and exact running image references passed.

Actual Google/Microsoft contact authorization remains unverified because both provider applications are still unconfigured. The owner completes that activation once; members only use the sign-in buttons. CSV/vCard/device imports remain available.
