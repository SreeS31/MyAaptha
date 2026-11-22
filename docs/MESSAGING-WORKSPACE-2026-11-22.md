# WhatsApp-style messaging workspace - 22 November 2026

Implemented the core chat/calling experience using MyAaptha's own identity and the established term **circles**. The previous My circles tree is preserved. Conversations stay in Messages; opening circle information displays a separate details pane rather than replacing the conversation.

## Delivery status

The code and Android test build are prepared for validation/publication. The new application release has **not yet been deployed to GCP**. The previous beta release remains active while explicit approval for the relay's public network ports is pending. Automatic approval review rejected that network change because its exact internet exposure had not been explicitly authorized.

Coturn was installed from the beta VM's Ubuntu repositories and configured with a protected signing secret, the existing issued TLS certificate, certificate renewal handling and resource limits. It is staged **inactive** pending network approval. No public firewall rule or relay VM tag was added. The protected environment contains staged TURN settings; the existing backend has not been restarted with the new wiring.

## Implemented behavior

| Area | Behavior |
| --- | --- |
| Messages workspace | Chat list, search, unread/people/circle/archive filters, message previews, conversation pane and responsive circle/contact information pane. Calls has its own recent-call view. |
| Existing messaging | Text, media/files, replies, reactions, forwarding, editing/deletion, message info, read receipts, message stars/pins and direct-chat pin/archive/mute/unread controls are retained. |
| Circle information | Name/description editing, posting permissions, searchable members, adding/removing members and administrator controls use the existing authorized circle API. |
| Voice notes | Web records microphone audio, provides playback preview and requires Send. Android records an audio attachment and requires Send. Cancelling/disposal releases microphone tracks; temporary native files are erased. |
| Individual calls | Shared audio/video call rooms, incoming answer/decline, mute, leave and recent call-back history. Block/account checks apply, including return calls. |
| Circle calls | Audio/video calls with server-enforced capacity of eight participants. Members join/leave; the creator can end the call for everyone. Membership is rechecked for room and signaling access. |
| Call controls | Web video screen sharing, native speaker toggle and camera switching, camera enable/disable, permission errors and device cleanup. No media is recorded by the calling server. |
| Cross-client contract | Web/native share durable room and signaling APIs. Signaling recipients are scoped to joined, authorized participants. Existing direct-call endpoints remain for older clients. |
| Retention | Abandoned signaling is purged after approximately five minutes by a once-per-minute job. Rooms expire after two hours or loss of joined heartbeats; recent-call history is retained for seven days, with up to 100 recent entries returned. |

## Limits and remaining parity work

This is not a claim of complete WhatsApp feature parity. Message end-to-end encryption, background/terminated-app incoming-call push, device linking/call handoff, large media-server-based group calls, polls/events, disappearing/view-once messages, sticker tooling and WhatsApp-style channels/communities are not implemented by this change. Native screen sharing and native hardware call/recording acceptance remain unverified. iOS audio-only voice-note recording is deferred: the installed WebRTC recorder requires a video track on iOS, so this release does not show a nonfunctional iOS microphone button. Circle-level favorites/archive/mute parity and full-history saved-message browsing also remain separate work.

The current group-call design is a small peer mesh with an eight-participant limit. [WhatsApp's calling features](https://www.whatsapp.com/calling) provide a useful broader reference, including larger group calls and other features beyond this release. No WhatsApp branding or proprietary implementation is included.

## API and schema

Migration V75 adds `communication_calls`, `communication_call_members` and `communication_call_signals`. Existing tables are not rewritten.

- `POST /api/network/meetings`: `{scope: DIRECT|CIRCLE, targetId, callType: AUDIO|VIDEO}`.
- `GET /api/network/meetings`: authorized active calls.
- `GET /api/network/meetings/history`: authorized recent calls.
- `GET /api/network/meetings/{roomKey}`: call details/participant heartbeat.
- `POST /api/network/meetings/{roomKey}/join`, `/leave`, `/end`.
- `POST /api/network/meetings/{roomKey}/signals`: `{recipientId, type: offer|answer|ice, payload}`.
- `GET /api/network/meetings/{roomKey}/signals?after=ID`: only signals addressed to the signed-in joined participant.

SDP is bounded and validated; UUID route keys do not use the numeric-ID validator. Signaling and history cleanup also cover abandoned clients. The existing authenticated `/api/network/calls/ice` endpoint issues short-lived relay credentials; the static signing key remains server-side.

## Pending network approval and activation

The concrete proposed firewall rule is on VPC `myaaptha-beta`, targets only a new `myaaptha-beta-turn` tag on VM `myaaptha-beta`, and allows source `0.0.0.0/0` to TCP 3478/5349 and UDP 3478/49160-49239. These are TURN listeners and a bounded media relay range. Authentication, TLS and short-lived credentials do not remove the fact that this changes public ingress.

After explicit approval: apply that scoped firewall rule/tag, activate the staged relay, deploy the reviewed compose overlay and scanned application images using the guarded backup/restore rollout, verify actual relayed media on HTTPS, then remove synthetic test data. Do not retry or work around the automatic-review rejection before approval. Keep the relay inactive and the previous beta application running until this activation can be completed.

Verification results and immutable image references will be added after validation. The Android artifact is a debug test build, not an app-store publication.
