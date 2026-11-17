# Interests and community groups — 17 November 2026

The Interests workspace now supports a categorized searchable catalogue of 410 hobbies/interests, multiple selections, custom interests, and saving/removing selections without a count quota. Existing comma-separated hobbies remain readable, and the profile editor uses the same picker. The dedicated save endpoint updates only hobbies, preserving unrelated profile and career changes.

Members can discover real groups by name/topic and area, create/edit their own groups, request membership, cancel requests, leave groups, and participate in paginated discussions after admin approval. Group creators review/approve/decline requests and can remove discussion messages. No product quota limits interests, groups created, or groups joined; lists paginate without hiding subsequent pages. Individual fields have input-length safeguards. A creator remains the group admin and cannot leave their own group in this release.

Examples such as Hyderabad Cycle Club, All India Shooter Club and Hyderabad Startups Club are suggestions, not fabricated live organizations. The directory displays groups actually created by members. Area is searchable text (city, region, country or worldwide); it does not collect device location. All signed-in members can read directory metadata; only approved group members can read discussions. Pending requester usernames are visible only to that group's creator.

Implementation: `/api/interests`, migration `V74__interest_groups.sql`, web `/interests`, shared profile picker. Existing private relationship circles are unaffected. Native Flutter group discovery screens are not included in this web request; existing native saved hobbies remain compatible.

Verification before release:

- Backend application builds successfully.
- Four backend HTTP/service scenarios passed, covering authentication, admin ownership, join/approval, pending/nonmember discussion denial, messaging/moderation, leaving, rejected-request resubmission, 350 interests with case-insensitive deduplication, unrelated profile preservation, and 27 created/joined groups across pages.
- Four desktop/mobile browser scenarios passed against the local production build with API fixtures: picker persistence/custom choices, group creation, approval, discussions/deletion, area filtering, cancellation, and no discussion request while membership is pending. Both authenticated UI scenarios passed WCAG A/AA automated checks and viewport overflow checks.
- The complete production browser run passed 33 scenarios and timed out navigating to the existing mobile diary at 900px. The isolated retry passed in 5.2 seconds (14.1 seconds including test startup). All 23 web unit checks and all 108 infrastructure checks passed. The final production build (including the shared profile picker) passed.
- Real provider delivery, physical native-device acceptance and capacity certification remain outside these checks. Browser fixtures are not evidence of live database writes.

Deployment must use the exact commit's scanned backend and frontend images after CI passes. Apply the additive V74 migration through the existing production migration job with a verified database backup; then update backend and frontend together. Preserve previous image digests. Do not deploy just the frontend: the new endpoints and tables are required. Do not rerun bootstrap, reset accounts or recreate database volumes.

`infrastructure/update_beta_interests.py` prepares that sequence for the existing beta. It validates immutable backend/frontend digests and VM identity, stops backend writers, takes a protected backup, restores it into a new temporary database, compares user counts, drops only that temporary database, runs migrations, starts backend/frontend, checks their running image references and HTTPS/API health, and restores previous application settings on failure. It never automatically restores the live database. The script's input/configuration boundary tests passed; its live deployment and restore path have not run in this session.

GCP authentication: an interactive PowerShell window was opened for `gcloud auth login`, with the installed Python path and the user's normal gcloud configuration directory. Local account readback was still empty during implementation. Cloud rollout is pending authenticated access and successful release validation; a Git push does not establish deployment.
