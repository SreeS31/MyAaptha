# MyAaptha launch board

View the board at **http://127.0.0.1:4317**, or open [Launch Board](index.html) directly in a browser. Start the local preview with `powershell -NoProfile -ExecutionPolicy Bypass -File infrastructure/start-launch-board.ps1`. It is a planning artifact and does not require application login, cloud setup or a running API. This board does not add a public administrative route to the application.

Snapshot: **22 October 2026**. Scope: **18 modules, 89 tracked subtasks, 60 recorded complete and 29 pending**. Four modules (profile/settings, relationships/people, timeline and documentation) have every tracked local subtask complete. Physical-device acceptance and other release gates remain separate. See [continued development results](DEVELOPMENT-CONTINUED-2026-10-17.md), [earlier development results](DEVELOPMENT-2026-10-17.md) and [discovery data review](DISCOVERY-REVIEW-2026-10-17.md). This is a curated launch scope, not a reconstruction of every historical ticket.

The newly delivered moderation queue (M08.5), manual health-entry parity (M09.5) and full web-bundle verifier (M15.9) add three explicitly identified completed engineering tasks to the original 86-task scope. The original 29 launch gates remain pending. See [18 October development results](DEVELOPMENT-2026-10-18.md).

## Reading progress

The top engineering panel shows the latest source baseline even if a saved browser plan is older: **68/68 applicable coding checks, 68/89 testing checks and 60/89 integration checks**. Twenty-one coding checks are N/A and excluded from the coding denominator. Eight tasks have local engineering verification but still need release acceptance. The expandable development ledger lists task updates and evidence; those updates are not additional newly completed tasks.

The 60/89 launch total counts only fully closed tasks. Fixes inside already closed tasks and partial progress toward staging/provider gates do not increase that total. Browser edits remain separate and are preserved.

## Views and controls

- **Board:** Before Launch, Immediately After, Post Launch and Done; card counts, completion bars, expandable subtasks and proposed owners. Drag cards or use their phase dropdown, including with a keyboard.
- **Module Status:** coding/testing/integration, task counts, dependencies, evidence links and edit controls.
- Search and filters support pending work and unfinished dependencies.
- Add/edit modules and subtasks. Moving a phase does not complete checks. Done requires all applicable checks to be done.
- Browser edits persist locally. JSON export/import transfers the full plan. CSV exports one row per subtask. Restore baseline discards browser edits after confirmation.

The baseline is [launch-data.json](launch-data.json); the readable report is [STATUS-2026-10-22.md](STATUS-2026-10-22.md). Source data is curated in `build_board.py` with development changes in `development-updates.json`; HTML is generated from `board-template.html`. Regenerate with `python docs/launch-board/build_board.py`. Existing browser edits are preserved; a revision notice identifies a newer source baseline until restored/imported explicitly.

## Assessment policy

Completed checks use source inspection and linked **historical local verification**. They do not mean freshly retested, deployed to production, approved by external reviewers, or identical web/native coverage. Pending includes verification and external gates. External approvals/configuration use N/A for coding. Owners are proposed teams. Dependencies and before/after/post placement are a proposed launch plan and can be edited.

The latest recorded 5,000-user capacity test failed its gates. Cloud setup, real-provider delivery, physical devices, production recovery, signing/store submission, legal/privacy approval and independent security acceptance remain pending. Optional features can be deferred explicitly rather than counted as completed. Old milestone claims of “20/20 complete” describe an older engineering scope, not public launch clearance.

## Verification

`node docs/launch-board/verify-board.cjs` runs the existing project Playwright dependency against a temporary browser context. It tests totals, filters, phase guard, edits, persistence, import/export, reset, evidence dialog and phone-width layouts. It modifies only temporary browser data and creates preview images. No application data, provider accounts or deployment settings are changed.

The [19 October continuation](DEVELOPMENT-2026-10-19.md) implements shared encrypted OAuth handoffs. It preserves the 60/89 closure count while real provider and staging acceptance remain open.

The [20 October continuation](DEVELOPMENT-2026-10-20.md) adds an offline rollback review planner. Live monitoring and rollback acceptance remain pending.

All pending source tasks now have explicit [completion requirements and next actions](PENDING-ACCEPTANCE-2026-10-20.md). The latest audit and actual Android release-signing work are in the 20 October report.

Hosted pages automatically check for a new source revision every minute and on tab focus. Load the updated page once to enable this. Current source evidence updates while saved browser-plan edits are preserved; offline file snapshots remain static.

For the exact distinction between developer work and owner/external inputs, see [who supplies each launch dependency](OWNER-INPUTS-2026-10-20.md). Shared inputs unblock multiple tasks; routine local development does not need repeated confirmation.

The [22 October continuation](DEVELOPMENT-2026-10-22.md) records verified call cleanup and storage integration. [Current owner-input checklist](LAUNCH-INPUTS-2026-10-22.md). Testing/integration remain engineering-owned; local evidence does not close provider/device/review gates.
