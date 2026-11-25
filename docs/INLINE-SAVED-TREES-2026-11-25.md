# Saved trees shown directly on the page

My trees previously showed a list of names; its diagram and display choices were only visible after opening the editor. Saved trees now use the main page as a diagram viewer, with a saved-tree selector, Modern / Heritage / Compact / Right-growing controls, gender colors, branch circles, expand/reset and zoom. Full saved-tree data is fetched rather than drawing the six-person card preview.

Trees start expanded, with incremental rendering for large trees. Collapsing a branch does not create a redundant “show more” action. Switching trees clears the old selection and diagram while the next tree loads. Edit tree and Edit person retain the existing reviewed-save and conflict protections. Deleting a tree keeps its contacts.

Native mobile uses the same full-data API and inline viewer. The editor reveals the selected person's ancestors when opened from the viewer. No backend schema or relationship data is changed; this release uses the existing owner-scoped relationship-tree API at schema 81.

Validation and deployment references will be recorded after release verification.
