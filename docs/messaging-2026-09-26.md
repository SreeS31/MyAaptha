# Messaging update - 26 September 2026

MyAaptha does not yet have complete WhatsApp feature parity. This update adds
working direct-chat management and forwarding across the shared API, web and
Flutter clients. It does not certify production capacity or physical-device calls.

## Added in this update

| Feature | Behavior |
| --- | --- |
| Archive / unarchive | Private, server-persisted. Archived conversations stay archived when new messages arrive. |
| Mute / unmute | Suppresses new direct-message notification creation and rechecks mute before queued notification dispatch. Messages are retained. Calls are unaffected. Mute lasts until explicitly removed. |
| Mark unread | A private reminder separate from actual unread message counts and receipt timestamps. Clear it manually or open the conversation from the inbox. |
| Inbox / Unread / Archived | Matching filters on web and native mobile. Unread excludes archived chats. |
| Forward | Choose a relationship or existing chat and explicitly confirm the recipient. Copies the message and any attachment into a new direct message with a Forwarded label. |
| Independent forwarded attachments | Copy through normal media validation, scanning and quota checks; deleting the original does not break the copy. Original sender identity, replies, flags and reactions are not copied. |
| Application help | The existing help chatbot can explain these controls from the shared help articles without needing a live AI key. |

Web: http://localhost:3000/messages. Choose **More** beside a conversation.
Native: **Messages > Chat actions**. Inside a chat choose **Message actions >
Forward**, choose a person, then **Send forward**. Existing stars, private message
pins, conversation pins and receipt settings remain available.

Settings are owner-scoped. Other participants do not inherit or see your settings.
Only participants can forward a source message. The destination must pass the same
relationship, account-status and blocking rules as a normal direct message.
Deleted messages cannot be forwarded. Forwarding is currently one recipient at a
time from direct messages; circle forwarding is not implemented.

Migration V61 adds direct_chat_settings. V62 adds the forwarded flag with a false
default for existing messages. Existing messages/passwords are preserved. The
active preview database was backed up to ignored
`.tools/preview/pre-messaging-settings.dump` before migration.

## Feature audit and remaining work

| Area | Status |
| --- | --- |
| Direct and circle messages, text search, attachments, replies, reactions | Existing implementation |
| Sender edit and delete for everyone | Existing implementation; edit/delete time limits are not WhatsApp-equivalent |
| Star, private message pin, conversation pin, direct read receipt privacy | Existing implementation, regression tested |
| Archive, mute, manual unread, forwarding | Added for direct chats in this update |
| Relationship broadcasts, blocking, presence and typing | Existing implementation |
| One-to-one audio/video calling | Signaling exists; real-device, NAT/TURN and interruption testing still needed |
| Shared/timed message pins | Missing; current message pins are private bookmarks |
| Delete for me / clear local conversation | Missing |
| Voice-note recorder, playback receipts and transcription | Missing dedicated voice-note workflow; audio file attachments are supported |
| Disappearing messages and view-once media | Missing |
| Message polls, stickers/GIF picker and live location sharing | Missing dedicated workflows |
| Circle equivalents of new direct-chat controls | Pending |
| End-to-end encrypted messages, device identity verification and encrypted chat backups | Missing; server storage encryption is not end-to-end encryption |
| Group audio/video calls | Missing |

This is an application audit, not a claim that every current WhatsApp product
feature or platform-specific behavior has been reproduced. Feature comparisons
were informed by the official [WhatsApp privacy overview](https://www.whatsapp.com/privacy),
[forwarding help](https://faq.whatsapp.com/887468535575482/?cms_platform=web), and
[voice-message overview](https://about.fb.com/news/2022/03/new-voice-message-features-on-whatsapp/).
There is no WhatsApp network interoperability.

## Validation

- API full verification: 123 passed, zero failures/errors/skips, real Redis enabled.
- Help update: 9 targeted tests passed after the full suite, including one new
  messaging-instructions test; the API was repackaged with the updated articles.
- Native mobile: 24 tests passed; Flutter analysis reported no issues.
- Web: production build passed; 11 unit tests passed. Existing nonblocking image
  optimization lint warnings remain.
- API regression tests cover ownership, partial setting updates, mute suppression,
  restored alerts after unmute, retained unread counts and read receipts, invalid
  requests, forwarding authorization and surviving original attachment deletion.
- Mobile widget tests exercise folders, settings and explicit forwarding consent.

- Android debug APK rebuilt at
  `mobile/flutter-app/build/app/outputs/flutter-apk/app-debug.apk`.
- Desktop and mobile-browser messaging walkthroughs: **2 passed** on the final
  build, including regular-member forwarding, automatic picker focus/visibility,
  persisted settings, stars/pins, and read-receipt privacy. Screenshots were reviewed.
- Final web, API and AI-service health checks returned HTTP 200. The local preview
  is running at http://localhost:3000.
- V61 and V62 were applied successfully on the local PostgreSQL preview.

These checks do not replace physical Android/iOS testing, signed release builds,
or capacity testing.

Local logs: `.tools/messaging-api-verify.log`, `.tools/messaging-help-package.log`,
`.tools/messaging-mobile-tests-final.log`, `.tools/messaging-mobile-analysis.log`,
`.tools/messaging-web-build-final.log`, `.tools/messaging-web-unit.log`,
`.tools/messaging-browser-final.log`, and `.tools/messaging-apk.log`.
