# Community navigation — 15 November 2026

The web menu now groups Feed, My posts, Followers, Following, Discover and Messages under Community. Dashboard, Relationships, Diary & Memories and personal records remain under My workspace. Account tools and profile are separate from social navigation. Existing URLs remain available.

Followers and Following have separate routes and selected states, a shared visual layout, page-local name search, paginated API results, useful empty/error states and profile links. Unfollow uses the existing authorized Role Model API. No follower totals are invented from a partial page of results. Following does not grant access to private diary entries or contact details.

My posts shows the signed-in member's shared entries. The social Feed excludes private diary entries; Diary & Memories retains them. The audience selector still defaults to Private. After saving, the interface explains whether the entry was saved to the diary or shared with the selected audience. Audience and authorization checks remain enforced by the existing backend.

Flutter exposes Feed, My posts, Followers and Following as Community sections, uses the same post filtering rules and presents the social destination earlier in navigation. Bundled fonts, accessible controls and the shared visual tokens remain in place. A native store release requires signing and separate publication.

These are Instagram-style navigation patterns for MyAaptha's own community. This change does not connect Instagram accounts, import their followers or publish to Instagram.

Regression coverage includes private/shared post separation, following versus follower actions, search and unfollow requests, desktop/mobile geometry, keyboard navigation, accessibility and native application tests. Fixtures use synthetic data rather than live accounts. The beta deployment replaces only the frontend image; accounts, database and media are preserved.
