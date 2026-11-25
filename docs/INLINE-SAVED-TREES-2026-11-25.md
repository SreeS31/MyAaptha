# Saved trees shown directly on the page

My trees previously showed a list of names; its diagram and display choices were only visible after opening the editor. Saved trees now use the main page as a diagram viewer, with a saved-tree selector, Modern / Heritage / Compact / Right-growing controls, gender colors, branch circles, expand/reset and zoom. Full saved-tree data is fetched rather than drawing the six-person card preview.

Trees start expanded, with incremental rendering for large trees. Collapsing a branch does not create a redundant “show more” action. Switching trees clears the old selection and diagram while the next tree loads. Edit tree and Edit person retain the existing reviewed-save and conflict protections. Deleting a tree keeps its contacts.

Native mobile uses the same full-data API and inline viewer. The editor reveals the selected person's ancestors when opened from the viewer. No backend schema or relationship data is changed; this release uses the existing owner-scoped relationship-tree API at schema 81.

Source: `5aea3bab8f60ca25d3b5d9611e448caf2d02c1d0`, tag `beta-20261125-inline-saved-trees-r1`.

- [CI](https://github.com/SreeS31/MyAaptha/actions/runs/45527671894) and [image validation/scans](https://github.com/SreeS31/MyAaptha/actions/runs/45527687812) passed on the exact release source.
- Backend: 321 tests, zero failures/errors, one skip. Browser: 98 scenarios completed (96 first-pass; two existing story scenarios passed after retry because hidden fallback fields made their label selectors ambiguous). All new inline-view scenarios passed. Web unit tests: 26 passed. Native: clean analysis, 140 passed and two expected skips.
- Desktop/mobile coverage verifies full 30-person data beyond the six-person card preview, expanded inline diagrams, all four layouts, tree switching, clearing the old diagram while loading, editing and viewport/accessibility checks. Native coverage also verifies initial node selection reveals its ancestors.
- Android test APK: `.tools/preview/MyAaptha-beta-inline-trees-20261125.apk`, SHA-256 `7fed8f442a054f0248c2bc45401e084c8c0a0c6539d3ca2d5bda1694dd3369c1`.

Deployment and live verification are recorded in `infrastructure/production/inline-trees-images-20261125.json`.

Beta deployment verified: exact image digests, schema 81 and HTTPS/API health UP. Backup `/opt/myaaptha-beta/runtime/release-backups/20261125T023748764250Z.dump` was restored into a disposable database and its user count verified before rollout. Four final live desktop/mobile scenarios passed, including direct inline diagrams, layout changes and Edit person / Edit tree. Both synthetic accounts and their contacts/trees were removed; 15 cleanup counts were zero. Google Contacts and authenticated TURN remain configured. Physical-device acceptance remains pending.
