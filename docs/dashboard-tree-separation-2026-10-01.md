# Dashboard and Relationship Tree separation

Dashboard remains at /dashboard and is the first navigation item for all roles. The existing administrator dashboard remains role-specific. The regular dashboard retains overview metrics, insights, timeline, contact import and shortcuts.

Relationship Tree is a separate authenticated route at /relationship-tree and the second navigation item. It uses the existing account-scoped tree and messaging behavior, including numbered levels, without rendering metrics, timeline, insights, import tools, circle directory or discovery panels. Relationship editing remains available in a collapsed tree control. No new authorization or access to other users' trees is introduced.

Mobile now opens a Dashboard overview from its first tab, with Relationship Tree as a separate screen and menu entry. Existing tree and broadcast widgets are reused. No new mobile installation package is produced.

Checks and screenshots are recorded under .tools/dashboard-tree-split-* and .tools/preview/tree-levels-*.png.

Validation: production web build and Flutter analysis passed. Desktop and mobile browser checks passed for navigation order, Dashboard title, tree-only content and actual level-limited delivery. Diary and follow-list regression checks passed on both viewports. One combined-run mobile test stopped at test-account login; its independent rerun passed.
