# Personal and community feature audit — 23 November 2026

**MyAaptha does not have full Instagram or WhatsApp parity.** This is a functional audit, not a claim that similarly named screens provide equivalent behaviour. The owner requested personal/community features first; commercial tools are deferred. The personal feature batch below was validated and deployed to the beta VM on 23 November 2026.

The comparison uses official product material current at the audit date:

- [WhatsApp messaging](https://www.whatsapp.com/messaging), [calling](https://www.whatsapp.com/calling), [privacy](https://www.whatsapp.com/privacy), [groups](https://www.whatsapp.com/groups), and [communities](https://faq.whatsapp.com/495856382464992).
- [WhatsApp events](https://about.fb.com/news/2026/11/whatsapp-events-brings-people-together-beyond-the-group-chat/) and [community planning](https://about.fb.com/news/2024/05/events-in-whatsapp-communities/).
- [Instagram Reels](https://about.fb.com/news/2020/08/introducing-instagram-reels/), [creation tools](https://about.fb.com/news/2023/11/new-ways-to-create-content-on-instagram/), and [reposts, map and Friends](https://about.fb.com/news/2025/08/new-instagram-features-help-you-connect/).

Product availability varies by device, account and region. The rows below describe MyAaptha's implementation, not every Meta experiment or regional rollout.

## Messaging and communities

| Feature | MyAaptha assessment |
| --- | --- |
| Individual and circle text chats | Implemented on web/native/API. |
| Photos, videos, documents and audio attachments | Implemented with authenticated media access, quotas and retention choices. File/size limits differ from WhatsApp. |
| Reply, reactions, forwarding, editing, deletion and message info | Implemented. Deletion permissions/time windows differ; message stars/pins are personal. |
| Delivery/read receipts, typing, online state and search | Implemented; polling rather than WhatsApp's delivery architecture. |
| Voice notes | Web recording is implemented. The 24 November update replaces native recording with an audio-only Android/iOS recorder and lifecycle tests; real iPhone acceptance remains pending. |
| Contact/circle information and member administration | Implemented, including ownership transfer and explicit sole-member circle removal. |
| Mute, themes, favourites, custom lists, export and private clearing | Implemented in the preceding release. A chat currently has one custom-list assignment. |
| Disappearing messages | Implemented for new messages, with scheduled cleanup. This does not recall exports/screenshots or provide view-once semantics. |
| Polls | Released in this batch: circle polls, single/multiple answers, changed/withdrawn votes, counts, close/remove controls and pagination. Available from Polls & events, not native message-bubble cards. |
| Events | Released in this batch: circle events, local-time entry/UTC storage and changed RSVPs. No guest/public invites, cover editor, plus-one handling or scheduled reminders yet. |
| Individual/circle audio and video | Implemented WebRTC media with authenticated TURN; maximum eight participants. Real phone hardware acceptance remains pending. |
| Screen share, camera and speaker controls | Web screen share; native camera/speaker controls. Native screen share is missing. |
| Background/terminated incoming calls | Missing end-to-end device integration. The notification outbox/webhook interface is not FCM/APNs/CallKit delivery. |
| Larger calls, media-server forwarding, waiting rooms, scheduled call links and handoff | Missing. Requires an SFU/service architecture and cross-device lifecycle work. |
| Communities spanning circles | Missing. Existing circle trees and interest groups are not WhatsApp community membership/announcement structures. |
| Public broadcast channels | Missing. Admin-only circles and relationship broadcasts are not equivalent to a channel directory with private subscriptions. |
| Status | Existing 24-hour image/video stories. This release adds text status and Close Friends audience; voice status/music/editor tools remain missing. |
| View-once media, video notes, stickers/GIF catalogues, contact cards and live location | Missing or incomplete. Ordinary media attachments are not equivalents. |
| Message end-to-end encryption | Missing. Current message entities store readable content on the server. HTTPS and infrastructure encryption do not provide an end-to-end message protocol. |
| Call security | WebRTC encrypted media transport is present. No claim of WhatsApp-equivalent independently authenticated identities or a reviewed multi-device protocol. |
| Linked companion devices and encrypted user backups | Authenticated sessions and operational database backups exist; companion-key linking and user-controlled encrypted backups do not. |
| Per-chat biometric lock and account/device privacy parity | Standard authentication, blocks and settings exist. Biometric chat locks and the full device privacy set are missing. |

## Social sharing

| Feature | MyAaptha assessment |
| --- | --- |
| Posts, captions, audience selection, media, likes, reactions and comments | Implemented on web/native/API. |
| Saves, pinning and sharing into permitted chats/circles | Implemented. This release fixes older saves disappearing beyond the latest-feed window. |
| Saved collections | Released in this batch: multiple named collections per saved post, current-audience checks and paginated retrieval. No collaborative collections yet. |
| Stories and view counts | Existing media stories. This release adds text, reactions, private replies and author-only viewer lists. |
| Close Friends | Released in this batch: author-controlled list for posts/stories, with block checks and access revocation. |
| Story archive/highlights | Released in this batch: opt-in private archive for 30 days after expiry; named highlights retain the original audience and underlying media-asset expiry. Full grouped highlight playback/editor parity remains incomplete. |
| Reels/video feed | Released in this batch: paginated shared-video feed, authenticated inline playback, like/save/comment/share, upload and playback lifecycle controls. Not an Instagram editor, ranking engine or remix system. |
| Story polls, questions, link stickers and mentions | Missing; circle polls do not provide story sticker tools. |
| Photo/video carousels | Missing; a standard post still has one attachment. |
| Filters, cropping, clip editing, covers, captions/transcription, remix and collaborative posts | Missing or incomplete. Licensed music is deferred with commercial/provider work. |
| Hashtags, mentions, tagging, location discovery and repost attribution | Attributed reposts were added on 24 November with original-audience checks. Dedicated hashtag/mention/location indexing and tagging consent controls remain missing. |
| Followers, following and profiles | Present through existing social/trust features. Full private-account follow requests, professional/profile-grid controls and Instagram-style relationship semantics are incomplete. |
| Explore and recommendations | Existing discovery is partial; no mature interest-ranking or content recommendation engine. |
| Notes, close-friend instant photos and shared recommendation feeds | Missing. |
| Live broadcast and co-hosting | Missing; peer group calls do not provide audience streaming. |
| Creator analytics, scheduling and content archive controls | Missing or incomplete. |
| Reporting, blocking and moderation | Present, but not a claim of Instagram-scale detection, appeal, parental controls or enforcement coverage. |

## Implementation boundaries and remaining work

This release implements a useful set of missing personal/community functions. It must **not** be presented as completion of every row above.

End-to-end message encryption needs a reviewed protocol/library, device key ownership and recovery decisions, identity verification, multi-device behaviour and a migration plan for existing readable messages. It changes server-side search, moderation and AI access. This release must not introduce homemade encryption or falsely label current messages end-to-end encrypted.

Reliable background calls need actual Firebase/APNs application configuration and platform incoming-call integration, followed by physical-device tests. Large calls/live broadcasts need a selected media service or operated SFU, capacity tests and deployment configuration. The repository's generic notification webhook and TURN server alone do not supply these features.

Commercial ads, shops, payments, paid subscriptions and licensed catalogues remain deferred by the owner's instruction. No provider credentials, media licences or payment accounts have been invented or committed.

## Release technical scope

Migration 77 adds circle activities/options/votes/RSVPs, Close Friends, story reactions, highlight metadata and saved collections. Story media becomes optional for text status. Only stories explicitly marked for archiving remain privately accessible to their author after expiry, for 30 additional days. The cleanup worker removes unhighlighted records after their selected expiry/archive period. Highlights never override media-asset storage expiry or their original audience.

Every activity read/write requires current circle membership. Only permitted members create activities; activity creators/circle admins close or delete them. Votes are scoped to their poll and serialized for replacement. Results expose counts and the caller's choice, not participant phone numbers. Close Friends lists and collections are private to their owner, and saved content is rechecked against current audience/block rules.

## Validation and deployment

Source: `d921e4fd2050d66133dce28214385810b02d3f2b`, tag `beta-20261123-personal-features-r1`.

- [CI](https://github.com/SreeS31/MyAaptha/actions/runs/45138617668) and [image validation/scans](https://github.com/SreeS31/MyAaptha/actions/runs/45138617663): passed.
- 76 browser scenarios and 26 web unit tests passed. Backend: 290 tests, zero failures/errors, one skip. Mobile: clean analysis, 124 passed and two expected skips.
- GCP image digests and schema 77 verified; HTTPS/API health UP. Database backup was restored into a disposable database and its user count verified before migration.
- Four live desktop/mobile feature and public-quality scenarios passed, including synthetic video upload/playback, story replies/reactions and audience revocation. Test uploads were removed through APIs; four exact synthetic accounts and their circles/messages were removed with guarded cleanup.
- Google Contacts configuration and authenticated TURN configuration/service were preserved. Physical-device playback and incoming-call acceptance remain pending.
- Matching Android debug test APK: `.tools/preview/MyAaptha-beta-personal-features-20261123.apk`, SHA-256 `0349bffa5e501b5ab194f00cec946f49574a8f3e708ce32657306b95876674e5`.

Immutable image and backup references are recorded in `infrastructure/production/personal-features-images-20261123.json`. This release does not complete all remaining parity rows.

## 24 November follow-up

Private frequent-call highlights and stars, RSS/Atom/YouTube public-feed previews and the native audio-only recorder are implemented in the [24 November follow-up](HIGHLIGHTS-EXTERNAL-FEEDS-2026-11-24.md). The public-feed actions are local saves/likes and confirmed original-link sharing; they do not automate Instagram personal-account access or upstream social actions. Message E2EE, background incoming-call integration, larger-call/live media architecture and the other incomplete rows remain outstanding. Provider setup and the encrypted/searchable chat model are still unresolved. Commercial features remain deferred.

Project setup status and encryption decisions can be saved under **Administration → Inputs needed** (`/project-inputs`), with the same administrator API and native mobile form. This tracks pending inputs; it does not activate providers or complete parity. See [tree views and project inputs](TREE-VIEWS-PROJECT-INPUTS-2026-11-24.md).
