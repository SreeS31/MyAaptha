# Combined Messages inbox and compact message actions

## Delivered behavior

- Web and Flutter navigation use **Messages**. Direct conversations and joined circles appear in one inbox, ordered by recent activity, with People, Circles and Unread filters. Existing direct-chat archive, mute and pin settings remain available.
- Circle previews and unread badges do not acknowledge messages. Opening a circle from the inbox opens its conversation.
- Web message actions use a compact keyboard-accessible menu. Info opens a dialog; Delete opens its two permitted choices; reactions have a separate compact picker. Copy, reply, forward, private star/pin, attachment download and author editing use the existing permission checks.
- Both clients offer a searchable forwarding picker for **1–10 people/circles combined**. Selections survive searching. An eleventh destination is disabled. Forwarding requires an explicit Send action.
- The API rejects empty, duplicate and over-limit selections. It checks every destination before creating copies, including direct-chat eligibility and circle posting restrictions. A forbidden destination rejects the whole batch.
- Forwarding works from either a direct or circle message into either destination type. Copies retain text and independently stored attachments, carry a Forwarded marker and do not inherit private stars/pins or reply metadata. Deleted and privately hidden source messages cannot be forwarded.
- Circle stars and pins are private per-user database records. Migration V64 adds them and the circle Forwarded marker. Media uploaded inside a failed transaction is scheduled for rollback cleanup.

## API additions

- `GET /api/network/chats/circles`: circle conversation summaries and unread counts.
- `POST /api/network/chats/forward`: `{sourceType, conversationId, messageId, targets:[{type,id}]}`; types are `DIRECT` and `CIRCLE`. Returns `{sent}`.
- `PUT /api/network/chats/circles/{circleId}/{messageId}/flags`: `{starred?,pinned?}`.
- The previous single-person direct-forward endpoint remains compatible.

## Validation

- Backend: seven messaging integration tests pass, including ten mixed destinations, eleven/empty/duplicate rejection, denied destinations, private flags, attachment preservation, deletion rules and unread-preview behavior.
- Flutter: five messaging widget tests pass, including the mixed ten-target limit and inbox filters; static analysis reports no issues.
- Web production build passes. Six browser scenarios pass across desktop Chrome and Pixel 7: direct-chat actions/receipts/settings, mixed forwarding and circle inbox navigation, and privately deleted circle history. The final four messaging scenarios are recorded in `.tools/unified-browser-final.log`; both history scenarios passed in `.tools/unified-browser.log`. Desktop and mobile screenshots are saved under `.tools/preview/unified-*.png`.

Local testing: http://localhost:3000/messages. The native app source is updated; distributing an installed mobile release still requires its normal build/signing process. This change does not establish production capacity or full WhatsApp feature parity.
