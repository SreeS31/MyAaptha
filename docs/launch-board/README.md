# MyAaptha launch board

View the board at **http://127.0.0.1:4317**, or open [Launch Board](index.html) directly in a browser. Start the local preview with `powershell -NoProfile -ExecutionPolicy Bypass -File infrastructure/start-launch-board.ps1`. It is a planning artifact and does not require application login, cloud setup or a running API. This board does not add a public administrative route to the application.

Current review: **8 November 2026**. Scope: **18 modules, 90 tracked subtasks, 61 recorded complete and 29 pending**. See [current module status](STATUS-2026-11-08.md), [review results and limits](PENDING-WORK-2026-11-08.md), [all pending acceptance requirements](PENDING-ACCEPTANCE-2026-11-08.md) and [dependency priorities](DEPENDENCY-PRIORITIES.md).

The original 86-task checklist includes four explicitly tracked engineering additions. Local tests and fixes do not close requirements for real providers, staging, physical devices or independent approval. The engineering panel calculates coding/testing/integration totals from the current source; N/A checks are excluded from each denominator. Expand **Engineering progress & remaining launch requirements** to see evidence and the full pending-task audit.

The board initially shows the latest verified source. **Status source** switches to a saved browser plan when one exists; source refresh preserves those edits. Recorded verification dates remain historical unless the current review explicitly reran the check.

[Latest local integration completion](LOCAL-INTEGRATION-COMPLETION-2026-11-06.md): all five previously skipped Redis, TLS/S3 and native PostgreSQL/scanner checks passed with isolated services. These results do not change the 29 external launch gates.

[7 November final security and integration evidence](SECURITY-INTEGRATION-2026-11-07.md): all nine GitHub CI jobs passed for the security-remediation source commit.

[7 November GitHub and security follow-up](GITHUB-HANDOFF-2026-11-07.md) records CI portability fixes and dependency remediation. It supplements the dated task review without granting release approval.

[8 November pending-task execution pack](ACCEPTANCE-EXECUTION-PACK-2026-11-08.md) provides scenarios, pass criteria and evidence requirements for all 29 open gates.

[Owner-confirmed storage policy](STORAGE-POLICY-2026-11-08.md): active files never expire automatically, 1 GB initially and storage plans up to 100 GB.

## Views and controls

- **Board:** Before Launch, Immediately After, Post Launch and Done; card counts, completion bars, expandable subtasks and proposed owners. Drag cards or use their phase dropdown, including with a keyboard.
- **Module Status:** coding/testing/integration, task counts, dependencies, evidence links and edit controls.
- Search and filters support pending work and unfinished dependencies.
- Add/edit modules and subtasks. Moving a phase does not complete checks. Done requires all applicable checks to be done.
- Browser edits persist locally. JSON export/import transfers the full plan. CSV exports one row per subtask. Restore baseline discards browser edits after confirmation.

The baseline is [launch-data.json](launch-data.json); the readable report is [STATUS-2026-11-08.md](STATUS-2026-11-08.md). Source data is curated in `build_board.py` with development changes in `development-updates.json`; HTML is generated from `board-template.html`. Regenerate with `python docs/launch-board/build_board.py`. Existing browser edits are preserved; a revision notice identifies a newer source baseline until restored/imported explicitly.

## Assessment policy

Completed checks use source inspection and linked **historical local verification**. They do not mean freshly retested, deployed to production, approved by external reviewers, or identical web/native coverage. Pending includes verification and external gates. External approvals/configuration use N/A for coding. Owners are proposed teams. Dependencies and before/after/post placement are a proposed launch plan and can be edited.

The latest recorded 5,000-user capacity test failed its gates. Cloud setup, real-provider delivery, physical devices, production recovery, signing/store submission, legal/privacy approval and independent security acceptance remain pending. Optional features can be deferred explicitly rather than counted as completed. Old milestone claims of “20/20 complete” describe an older engineering scope, not public launch clearance.

## Verification

`python infrastructure/verify_launch_board.py` starts an isolated read-only loopback server and runs the existing project Playwright dependency against a temporary browser context. It tests totals, filters, phase guard, edits, persistence, import/export, reset, evidence dialog and phone-width layouts. It checks live source refresh and saved-plan preservation as well as the board interactions. GitHub CI runs this command on feature branches and pull requests. It modifies only temporary browser data and creates preview images. No application data, provider accounts or deployment settings are changed.

The [19 October continuation](DEVELOPMENT-2026-10-19.md) implements shared encrypted OAuth handoffs. It preserves the 60/89 closure count while real provider and staging acceptance remain open.

The [20 October continuation](DEVELOPMENT-2026-10-20.md) adds an offline rollback review planner. Live monitoring and rollback acceptance remain pending.

All pending source tasks now have explicit [completion requirements and next actions](PENDING-ACCEPTANCE-2026-10-20.md). The latest audit and actual Android release-signing work are in the 20 October report.

Hosted pages automatically check for a new source revision every minute and on tab focus. Load the updated page once to enable this. Current source evidence updates while saved browser-plan edits are preserved; offline file snapshots remain static.

For the exact distinction between developer work and owner/external inputs, see [who supplies each launch dependency](OWNER-INPUTS-2026-10-20.md). Shared inputs unblock multiple tasks; routine local development does not need repeated confirmation.

The [22 October continuation](DEVELOPMENT-2026-10-22.md) records verified call cleanup and storage integration. [Current owner-input checklist](LAUNCH-INPUTS-2026-10-22.md). Testing/integration remain engineering-owned; local evidence does not close provider/device/review gates.
