# Simple contact sign-in — 20 November 2026

MyAaptha members now choose **Sign in with Google** or **Sign in with Microsoft**, select an account on the provider's page, approve read-only access when needed, and review contacts/circles before saving. Members never register OAuth clients, handle JSON files or enter application credentials.

Removed mandatory email-entry forms from Contacts and the older contact organizer on web/mobile. Email hints remain optional in the API for existing clients. The provider account chooser handles account selection; Google is no longer forced to repeat its consent screen on every import. State, PKCE, read-only scopes, ownership checks, temporary result storage and explicit saving consent remain in place.

Provider sign-in starts directly from its button. Saving consent and circle selections appear with the contact preview. File/device import remains available under **Other ways to import**. Unavailable service messages are written for members and do not ask them to configure credentials. No contacts are saved by signing in alone.

The Google/Microsoft OAuth application is still a **one-time MyAaptha owner/deployment configuration** shared by all members. Current beta provider credentials remain absent. This release changes the member experience; it does not fabricate provider credentials or claim an actual mailbox authorization. Activation tooling and the owner-only setup guide already exist in the repository.

Verification and deployment evidence will be recorded after release validation. No database migration is required.

Local validation: frontend production build, 50 browser checks, 26 web unit tests, 116 native tests (two expected live integration skips), clean Flutter analysis, and 18 targeted backend OAuth/address-book cases. The account-chooser assertions were repeated after removing forced repeat consent. Popup lifecycle checks are recorded with release verification.

Android debug test build: `.tools/preview/MyAaptha-beta-contact-signin-20261120.apk`; SHA-256 `f2c56f4997f38df0a05e3079f0df8c97156d7afec06877561b15c3fadeeaa399`. This is a test APK, not an app-store publication.
