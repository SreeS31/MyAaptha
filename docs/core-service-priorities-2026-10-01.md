# Core service priorities

Updated navigation: Dashboard is first, Relationship Tree is second, followed by Diary & memories, Following & followers, Messages and Circles. See dashboard-tree-separation-2026-10-01.md for the corrected separate pages. Contacts, timeline, finance and health sit under Personal tools. Mobile More uses the same ordering and exposes the new follow lists.

The relationship tree and existing broadcast controls now precede insights, timeline and contact-import tools on the dashboard. Add relationship, Message your tree and Write a memory are directly accessible.

The diary composer comes before short-lived stories. Every draft shows its selected audience in plain language, and every saved card carries a separate audience badge. After saving, the next draft defaults to PRIVATE, preventing a previous public selection from carrying into a new entry. Compact entry menus replace permanently visible Edit/Delete buttons. Pastel accents distinguish private diary entries.

Following and Followers use existing Role Model follow records. The authenticated API returns only the current account's list, with 30-person pagination; it does not expose contact fields. Web and mobile support viewing both directions and unfollowing. This does not expand the existing policy to following arbitrary accounts or give followers access to diary content.

## Validation
Production web build and Flutter analysis passed. Five backend tests passed, covering existing broadcasts, social visibility and sharing restrictions, and trust/follow-list account isolation. Both desktop and mobile browser tests passed: private entries stay hidden from another account, sharing a public entry resets the next draft to PRIVATE, and follow lists/unfollowing work. Screenshots were reviewed. Final browser evidence is recorded in .tools/core-services-browser-final.log.

## Remaining work
Update: numbered level selection is implemented in the subsequent tree-level messaging change; see tree-level-messaging-2026-10-01.md. Long-term memory retention also requires deployment backup, recovery and storage policies; no guarantee of permanent storage is made by this UI change. Native mobile source is updated, but no mobile installation package was produced.
