# Tree-level messaging

Web and native mobile now send the optional `levels` parameter to both broadcast preview and send endpoints. Select 1 through 10 levels, or Whole branch in branch mode.

- Level (HORIZONTAL): exactly N child links below the selected starting person. The starting person is excluded.
- Branch (VERTICAL): the starting person plus connections up to N links below. Whole branch removes the depth limit.
- The sender is never a recipient. Only relationships owned by the sender are traversed. Duplicate edges and cycles cannot repeat recipients or cross back through the sender into another branch.
- Managed/inactive accounts are excluded as before; actual direct-message access checks still apply on sending. The existing maximum of 500 recipients remains. No automatic broadcast occurs: the user presses Send.
- Changing the level clears the preview. Existing clients that omit levels retain their one-generation or whole-branch behavior.

API: GET /api/network/broadcasts/preview and multipart POST /api/network/broadcasts accept optional integer levels (1?10). Invalid supplied depths are rejected. No database migration is required.

Validation: seven backend tests passed for legacy selections, bounded/exact levels, invalid inputs, ownership, cycles and send recipients. Production web build and Flutter analysis passed. The mobile widget test passed for depth selection and preview invalidation. Both desktop and mobile browser tests passed, checking actual delivery to only the selected second-level recipient and the one-level branch preview. Logs use the .tools/tree-levels-* prefix. The native mobile source is updated; no installed mobile package is produced.
