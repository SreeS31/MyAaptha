# Relationship tree branch controls - 24 October 2026

## Reproduced failure

The visible plus marker and the person-name button overlapped. When the name button was hovered, the shared hover filter gave it its own painting layer, allowing it to intercept the marker's click. Selecting a name opens the details panel; repeating the plus click in that state could leave the branch collapsed, matching the reported screenshot.

A direct pointer jump to the marker initially passed, so the regression was refined to select/hover the name first and then click the visible plus centre. That scenario failed before the fix because the branch remained collapsed. Evidence: `.tools/launch-board/branch-controls-hover-before.log`.

## Change

The name button now starts beside the branch marker rather than covering it. Its width is reduced by the matching margin, preserving text alignment. The marker also has an explicit stacking order. Branch expansion state, graph edges, stored relationships and access rules are unchanged. The native Flutter chain already uses separate details and branch buttons and did not need this CSS fix.

## Verification

The four existing chain-layout checks passed, including cycle safety, disconnected branches and a 2,000-person deep chain. The browser regression uses synthetic relationship responses and a dedicated test account. It exercises mouse/touch plus clicks after selecting the name, nested expansion, details-panel expansion/collapse, keyboard collapse and Expand all. Final browser/build results are recorded below after installing the reviewed build.

Final result: production web build passed; both desktop and mobile-web branch-control scenarios passed (2/2), with zero recorded page errors. Mouse, touch, keyboard, nested branches and side-panel actions passed. The four layout tests also passed (6 focused cases total). Final logs: `branch-controls-web-build.log`, `branch-controls-after.log`, `branch-controls-layout-tests.log`. Tree and API health endpoints returned HTTP 200. No relationship records or API contracts were changed.

API, assembled web and unchanged native debug APK identities verified (`allPresent=true`, `matches=true`, `releaseApproved=false`), frozen in `.tools/launch-board/build-identities-tree-branch-20261024.json`. Desktop/phone screenshots were reviewed.
