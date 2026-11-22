# WhatsApp-style messaging workspace - 22 November 2026

Implemented the core chat/calling experience using MyAaptha's own identity and the established term **circles**. The previous My circles tree is preserved. Conversations stay in Messages; opening circle information displays a separate details pane rather than replacing the conversation.

## Delivery status

The application source is published as commit `3094bd0e14792816944ce42e18ae72fcf472c43d`, tagged `beta-20261122-messaging-r1`. CI and scanned image validation passed. The validated backend and frontend images are deployed to the GCP beta VM with schema 75. The user explicitly approved the scoped public relay ports before activation.

Coturn was installed from the beta VM's Ubuntu repositories and configured with a protected signing secret, the existing issued TLS certificate, certificate renewal handling and resource limits. The relay is active. The approved `myaaptha-beta-call-relay` firewall rule applies only to the `myaaptha-beta-turn` tag on the beta VM; the deployed backend requires the configured relay.

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

## Approved relay network and deployment

The approved firewall rule is on VPC `myaaptha-beta`, targets only the `myaaptha-beta-turn` tag on VM `myaaptha-beta`, and allows source `0.0.0.0/0` to TCP 3478/5349 and UDP 3478/49160-49239. These are TURN listeners and a bounded media relay range. Authentication, TLS and short-lived credentials do not remove the fact that this changes public ingress.

After explicit user approval, the scoped firewall rule/tag was applied and the relay activated. The guarded rollout verified a database backup restore before applying migration 75. The SSH session dropped during container health checks; an independent reconnect confirmed the exact immutable image digests, reviewed overlay checksum, relay wiring and healthy public API.

## Validation and release artifacts

- [CI run 44985463513](https://github.com/SreeS31/MyAaptha/actions/runs/44985463513): all jobs passed. Two existing diary layout checks needed retries and then passed.
- [Image validation run 44985463594](https://github.com/SreeS31/MyAaptha/actions/runs/44985463594): all validation and image scans passed, including an independent clean run of all 64 browser scenarios and 26 web unit tests.
- Local backend call coverage: six passing tests. Relay configuration: three passing tests. Native analysis: no issues; native tests: 119 passed and two expected opt-in skips.
- Live GCP tests passed for individual audio forced through TLS TURN and three-person circle video forced through UDP TURN, on both desktop and mobile browser layouts. All participants had connected peers, selected relay candidates and nonzero received RTP media. Synthetic camera/microphone devices were used; real phone hardware acceptance remains pending.
- Immutable backend/frontend image references, overlay hashes, prior release references and deployment evidence are recorded in [the release manifest](../infrastructure/production/messaging-images-20261122.json). Migration 75 has been applied; the previous release used schema 74. The database backup is `/opt/myaaptha-beta/runtime/release-backups/20261122T111058747878Z.dump`.
- Android artifact: `.tools/preview/MyAaptha-beta-messaging-20261122.apk`, SHA256 `7bc7f9f834971425832c2e6f66d8dd47984c9db83b6afa8f70d47bd617f1acf3`. This is a debug test build for the new backend, not an app-store publication.

This release implements the core features listed above. It does not establish full WhatsApp feature parity. In particular, end-to-end message encryption, background incoming-call push, large SFU calls and iOS audio-only voice recording remain pending.

## Final live verification

All six opt-in live scenarios passed: four actual relayed-media call scenarios and two public navigation/accessibility/viewport checks. The ten exact synthetic accounts and their contacts, owned circles, call rooms, membership and signaling rows were removed; remaining fixture counts were zero. Final HTTPS API health was UP. Google Contacts credentials remain configured; Microsoft Contacts credentials are not configured.
