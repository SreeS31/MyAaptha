# Circle menu and shared chat options

The Messages menu uses **Circle info** for circles and **Contact info** for individuals. Circle administrators can open Add member directly, edit the name, description and posting permissions, search members, promote/demote administrators and remove members. The creator remains an admin until ownership is explicitly transferred when exiting.

The web and Flutter clients share `/api/network/chats/workspace`:

- `GET /`: personal favourites and custom-list assignments for inbox filters.
- `GET /{kind}/{target}` and `PUT /{kind}/{target}`: theme, favourite, list, timed mute and shared new-message timer. `kind` is `DIRECT` or `CIRCLE`. Circle timers require an administrator; individual timers require an authorized connection.
- `DELETE /{kind}/{target}/history`: hides existing history only for the caller. Other participants keep their copies.
- `GET /{kind}/{target}/export?before=...`: pages of up to 500 visible text records with attachment names. Clients page the full history and save JSON. Media bytes are not included.
- `POST /CIRCLE/{target}/exit`: members can leave. Creators must supply another active administrator as `successorId`; access is revoked and their call participation is cleaned up. A sole creator can explicitly confirm removal of the empty-member circle and its messages while retaining private contacts.

Themes, favourites, a named custom list and mute choices are private to each user and synchronize between devices. The new-message disappearing timer is shared by the conversation: off, 24 hours, seven days or 90 days. Changing it does not rewrite deadlines on existing messages. A scheduled worker clears expired text and attachment references, deletes media through the established storage lifecycle and scrubs server notification previews. Cleanup runs every minute in bounded batches. Exports, screenshots and notifications already delivered to external devices cannot be recalled.

Message selection provides copy, star and delete-for-me actions on both clients. Existing single-message forwarding, replies, reactions, edit/delete rules, media, starred and pinned views, voice notes and audio/video calls are preserved. Mute suppresses new server message notifications and retains the existing direct-chat controls. It does not disable incoming call handling.

Migration 76 adds chat workspace settings, shared timers and expiry jobs. Existing message tables and API formats remain compatible with the previous beta release. No additional public ports or OAuth scopes are needed.

The application is deployed from commit `32d74b7a40cce8d8f40dcdd39d6af32971fed5cf`, tag `beta-20261123-circle-menu-r2`. [CI](https://github.com/SreeS31/MyAaptha/actions/runs/45094471078) and [image validation/security scans](https://github.com/SreeS31/MyAaptha/actions/runs/45094471573) passed. Browser validation completed all 66 scenarios: 64 first-pass successes and two existing diary-layout checks that passed on retry. Web unit tests: 26 passed; native tests: 121 passed and two expected opt-in skips; native analysis: no issues. Five local chat-lifecycle API tests passed. This change covers the referenced circle/chat menu; it does not add end-to-end encryption, background call push or every WhatsApp product feature.

Immutable image digests, overlay hash, APK checksum and deployment evidence are recorded in [the release manifest](../infrastructure/production/circle-menu-images-20261123.json). Migration 76 is applied. The fresh database backup was restored and verified before rollout: `/opt/myaaptha-beta/runtime/release-backups/20261123T023123225170Z.dump`. Google Contacts and the authenticated TLS/UDP call relay remain configured. The Android test APK is `.tools/preview/MyAaptha-beta-circle-menu-20261123.apk`; it is not an app-store publication.

The four opt-in live checks passed on GCP: desktop and mobile browser circle workflows plus public navigation/accessibility checks on both layouts. They verified member addition and admin promotion, private themes, shared timers, clear-for-me versus another member's retained history, ownership transfer, revoked access and explicit sole-member removal. The live harness was corrected for the current sign-in caption, async dialog completion and transfer dropdown before this successful run.

Seven exact synthetic identities, including interrupted harness attempts, were removed with guarded cleanup. Remaining test account/contact/circle/call/member/signal counts were zero. Final API health was UP and schema version was 76. Real phone hardware acceptance remains pending; browser mobile-layout checks and native unit/widget tests are not a substitute for device testing.
