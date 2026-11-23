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

Validation and deployment evidence will be recorded after the final checks. This change covers the referenced circle/chat menu; it does not add end-to-end encryption, background call push or every WhatsApp product feature.
