# Contact import and circle wording — 19 November 2026

The screenshot's disabled buttons came from missing Google/Microsoft OAuth app credentials on the beta backend. No credentials were present in the container, integration files or local encrypted provider store. The Google People API has now been enabled; a real owner-supplied OAuth Web application remains necessary for live mailbox authorization. See [provider setup](CONTACT-PROVIDER-SETUP-2026-11-19.md). GCP deployment sign-in does not supply these application credentials.

The Contacts and dashboard import controls now validate email and consent, explain missing provider setup, and refresh provider readiness instead of leaving valid email addresses behind permanently disabled buttons. A blocked popup is detected before allocating an OAuth attempt. Real provider access still requires the member's own read-only authorization; no email password is requested.

Review now retains contacts with a name, valid phone or valid email, including email-only provider contacts. Empty rows are skipped. Contact data is saved only after review, through the existing idempotent API batches. Importing does not create accounts, invitations, relationships or messaging memberships.

Circle suggestions use provider labels, organizations, existing circle names, and shared explicit name tags (hashtags, parentheses, suffixes or acronyms). Removed the six-phone requirement, the three hardcoded community tags, the mobile catch-all Imported contacts circle, and the 500-circle automatic-organization cap. A small explicit label can form a circle. Suggested assignments remain editable and deselectable. Web and native run the same shared regression fixtures. Existing API field lengths and per-contact bounds remain unchanged.

Messaging consistently says Circles, New circle, Circle name and Create circle on web/mobile. Its existing CIRCLE conversation type and compatible API routes are preserved.

The beta compose overlay now accepts protected backend-only provider settings. The owner credential installer checks the project/VM, exact callback, file permissions, runtime environment application and backend health without printing secret values. The rollout helper checks the exact previous overlay checksum and restores configuration on failure, alongside the existing database backup/restore and immutable-image guards.

Local checks completed: 16 backend contact/OAuth tests, 26 web unit tests, 116 mobile tests (two expected opt-in integration skips), 114 infrastructure tests, clean Flutter analysis and frontend production build. Browser regression and deployment evidence will be recorded after release validation. Synthetic provider tests do not establish access to a real Google or Microsoft account.

Deployment: pending scanned release images. Live provider activation: awaiting owner OAuth application credentials.

Android debug test APK: `.tools/preview/MyAaptha-beta-contacts-20261119.apk`, API origin `https://35-244-31-192.sslip.io`, SHA-256 `1095ccc6d392ad9b48715f2045eba07e6b965d29594f600120dc4690f6c21192`. This is a test build, not an app-store publication.
