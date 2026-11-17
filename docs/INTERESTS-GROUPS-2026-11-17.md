# Interests and community groups — 17 November 2026

**Deployment completed and live checks passed. See the completed GCP deployment section below.**

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

GCP authentication: an interactive PowerShell window was opened for `gcloud auth login`, with the installed Python path and the user's normal gcloud configuration directory. Local account readback was still empty during implementation. This initial authentication blocker was subsequently resolved; the completed rollout is recorded below.


## Validated release

Application commit `10bb6c21b52d11c8010ec0b8590119914760c654`, tag `beta-20261117-interests-r1`:

- [Full branch CI](https://github.com/SreeS31/MyAaptha/actions/runs/44022870941) passed all jobs, including backend, frontend, mobile, AI, infrastructure, dependency security and production smoke tests.
- [Beta release workflow](https://github.com/SreeS31/MyAaptha/actions/runs/44022937142) passed application validation and all five container build/runtime/security gates. The backend/frontend manifests are anonymously accessible by immutable digest.
- Final local production-build Interests checks, including refreshing pending membership after approval, passed all four desktop/mobile scenarios. Mobile screenshots were inspected. This was pre-deployment validation; the completed rollout is recorded below.
- [Exact deployment inputs](../infrastructure/production/interests-images-20261117.json) record the validated application commit and images. The other running service images are retained during this rollout.

The completed rollout used these commands from the authenticated checkout:

```bash
gcloud compute scp infrastructure/update_beta_interests.py myaaptha-beta:/tmp/myaaptha-update-interests-20261117.py --zone=asia-south1-a --project=project-5c36c021-87c7-4cfc-833 --tunnel-through-iap
gcloud compute ssh myaaptha-beta --zone=asia-south1-a --project=project-5c36c021-87c7-4cfc-833 --tunnel-through-iap --command='sudo python3 /tmp/myaaptha-update-interests-20261117.py --backend ghcr.io/srees31/myaaptha-backend@sha256:c72ed226492b5a5749e929de04c8436503d9cf4e2cac65fcb3ebcbbe5d87d157 --frontend ghcr.io/srees31/myaaptha-frontend@sha256:3c5eac6190ad7a0444b367e3fd13e62a22eb68ae3d8dd0ebdfe4f79c8cc3cda3'
```

The live acceptance check below verified persistence, a second user's request, creator approval, discussion isolation, posting and leaving. Local fixture tests and a healthy landing page alone cannot establish these live workflows.

If automatic browser opening does not work, open PowerShell in this repository and run:

```powershell
$env:CLOUDSDK_PYTHON = 'C:/Program Files/Python312/python.exe'
$env:CLOUDSDK_CONFIG = 'C:/Users/vighn/AppData/Roaming/gcloud'
& ./.tools/gcloud-portable/google-cloud-sdk/bin/gcloud.cmd auth login --no-launch-browser
```

Open the printed sign-in link manually and complete the prompts in that PowerShell window. Do not send authorization codes or tokens in chat. The GCP account must have access to the existing beta project.


## Completed GCP deployment - 17 November 2026

**Live: https://35-244-31-192.sslip.io/interests**

- Local GCP sign-in was confirmed, and IAP SSH reached the existing `myaaptha-beta` VM in `asia-south1-a`.
- The guarded updater pulled the exact validated backend/frontend digests above. The other running service images and existing accounts/media were preserved.
- Backend writers were stopped. A fresh custom-format PostgreSQL backup was restored into a new temporary database, and the restored user count matched the source. The temporary restore database was then dropped.
- Protected backup: `/opt/myaaptha-beta/runtime/release-backups/20261117T160204931682Z.dump`. The previous protected environment file is retained beside it for application rollback.
- Flyway applied the single pending migration V74 successfully. Backend/frontend health checks passed, their running image references matched the approved digests, and HTTPS API health returned `UP`.
- Live synthetic API acceptance passed: account-scoped saved interests, group creation/discovery by area/topic, join request, admin-only request visibility/approval, denial of discussion access before approval, posting after approval, creator moderation, and loss of access after leaving. Synthetic refresh sessions were logged out.
- The temporary group and both synthetic accounts were removed in an identity-checked transaction. No customer account or group was used for testing.
- Both desktop and mobile live public browser scenarios passed navigation, WCAG automated accessibility checks, viewport checks and browser-error checks. The live `/interests` response separately returned HTTP 200 and contained the new workspace headings/actions. These browser scenarios are public-page checks; the authenticated group flow was checked through the real live APIs.
- Local ignored evidence: `.tools/interests-gcp-rollout-20261117.log`, `.tools/interests-live-acceptance-20261117.json`, `.tools/interests-live-cleanup-20261117.log`, `.tools/interests-deployed-browser-20261117.log`.

Reload the Interests page to load the deployed application bundle. Real clubs appear when members create them; example club names were not published as fabricated organizations.
