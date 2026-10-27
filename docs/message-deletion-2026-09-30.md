# Message information and deletion controls

Web messages expose a compact **Info** control and a **Delete** control that opens **Delete for me** and, when authorized by the API, **Delete for all**. The Flutter action menu exposes Info and opens a deletion choice sheet.

## MyAaptha policy

- Delete for me is private to the signed-in account and persists across devices. It does not delete anyone else's message or attachment.
- In direct conversations, only the sender can delete for all.
- In circles, only current circle admins can delete for all, including messages written by another member. Ordinary members cannot delete their own group messages for all.
- Delete for all requires an age strictly below 24 hours and unread recipients. It expires when all recipients have read the message or 24 hours have elapsed, whichever comes first. The direct-chat rule uses the stored read state even when read receipts are hidden.
- Group read eligibility uses current circle membership, excluding the author, and existing circle read records. Circle reads currently reflect fetching the conversation, rather than per-message viewport acknowledgement.
- Server transactions check authorization and eligibility; a stale client cannot override them. Message locks serialize deletion with read acknowledgement and message edits.

This is the stricter interpretation of the user's time/read requirement. WhatsApp's published window differs (about two days); see [WhatsApp's deletion help](https://faq.whatsapp.com/1370476507114859/?cms_platform=web&helpref=faq_content). This change does not claim complete WhatsApp feature parity.

## Storage and client contract

Migration `V63__private_message_deletions.sql` adds participant-specific direct-message flags and the `circle_post_hidden` table. Existing messages default to visible.

- `DELETE /api/network/messages/with/{otherUserId}/{messageId}/for-me`
- `DELETE /api/network/circles/{circleId}/posts/{postId}/for-me`

These return 204. Existing DELETE routes continue to mean delete for all and now enforce the policy. DTOs add `canDeleteForAll` and `hiddenForMe`.

Cursor pages include redacted hidden-message markers so merging refreshed pages cannot restore hidden content and pagination can still advance. Web and Flutter skip those markers. Search, saved messages, conversation previews, and unread counts exclude private deletions; direct attachment access and forwarding reject hidden sources. Replies to privately hidden direct messages receive an unavailable preview. Visible circle replies remain accessible if their parent was hidden.

## Verification

- Nine backend tests passed across `MessageDeletionTest`, `MessageFeaturesTest`, and `NetworkControllerTest`; migration also applied to the local PostgreSQL preview.
- Web production build passed.
- Desktop and mobile browser messaging scenarios passed, including Info, both deletion choices, hide-after-reload, recipient-copy preservation, and actual delete-for-all through the UI.
- Flutter analysis passed and four mobile messaging regression tests passed. No native device or APK installation was performed in this change.
- Desktop and mobile circle-history regressions passed with 55 messages and ten private deletions. Earlier history remained reachable and hidden messages stayed absent. The initial test attempt omitted expanding My circles; the corrected user workflow passed.
- Evidence: `.tools/message-delete-backend.log`, `.tools/message-delete-web-final.log`, `.tools/message-delete-browser.log`, `.tools/message-delete-flutter-final.log`, `.tools/message-delete-mobile-tests.log`.
- Circle history evidence: `.tools/message-delete-history-final.log`.

Local test URL: http://localhost:3000/messages
