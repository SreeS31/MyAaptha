# Workspace navigation reorganization

The main web sidebar and Flutter drawer/desktop rail use the same nine categories. Existing URLs, APIs, ownership rules and stored records remain in place.

| Main menu | Contents |
|---|---|
| Dashboard | Overview, Life timeline, My profile, Trust center |
| Relationships | Relationship tree and existing relationship actions |
| Diary & Memories | Personal entries, attachments and saved memories |
| Health | Reports, measurements and existing health tools |
| Finance | Transactions, insights, bills, warranties and renewal reminders |
| Career | Existing education and employment profile fields |
| Interests | Existing hobbies profile field |
| Messages | Personal/group inbox, circle management, contacts and people discovery |
| Online Feed | Updates, stories, thoughts, audience controls, following and followers |

Account & tools keeps settings, blocked accounts, sessions, AI controls, help, reports and moderation. Web administrator security/error tools retain their existing access restrictions. Notification entry points and sign out remain available. Flutter keeps a short bottom bar and exposes all nine categories in the drawer; its desktop rail scrolls on shorter windows.

## Review view

Open `/menu-comparison` on the web, or **Menu comparison** in the mobile drawer/Account & tools. The review lists all 19 previous web menu destinations beside their new locations and provides direct links. This temporary view is available until the owner chooses to remove it. It does not switch permissions or delete the previous pages.

The comparison includes the web-only administrator security/error destination; Flutter explicitly identifies it as a web administration tool rather than claiming a native screen exists.

## Data and compatibility

Career and Interests reuse `/api/profile/me`; section saves fetch the latest profile and modify only their section. No new parallel profile store or database migration is introduced. Existing profile pages also expose Interests, so values remain visible in both contexts. Diary defaults to the account's entries; Online Feed exposes the existing shared feed, with private as the default composer audience. Existing targeted web post links bypass the diary-only initial filter. Existing saved posts and all audience choices remain available.

Messages retains direct/group/circle conversations, calling, search, unread filters, pins, mute and archive actions. The section tabs provide contacts and circle management without duplicating those items in the main sidebar. Previously opened Flutter section bodies retain their state while switching tabs; unopened tabs load lazily. Returning to a read-only profile refreshes saved data; open editors/uploads are preserved, and cancelling an editor reloads current saved values.

## Verification

Verification evidence is recorded in `docs/launch-board/NAVIGATION-2026-10-24.md`. Production distribution and physical-device acceptance remain separate from local builds and automated checks.
