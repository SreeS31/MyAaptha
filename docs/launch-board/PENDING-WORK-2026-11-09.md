# Go-live preparation ? 9 November 2026

**Status: not approved for public launch.** 61 of 90 tracked tasks remain recorded complete. There are 26 website acceptance tasks and 3 additional native-only tasks. Today's UI work does not grant external acceptance.

## Delivered today

- Landing page explains the initial 1 GB free allowance, paid-plan storage up to 100 GB, user-selected expiry and user-controlled deletion when full. No checkout or plan pricing is implied.
- Upload-expiry dialog describes the selected consequence before upload, announces changes to assistive technology, restores prior focus, provides 44 px controls and wraps actions on phones. Never remains the default when offered; unavailable choices cannot be submitted.
- Desktop and Pixel 7 browser tests cover all 12 options, default Never, API multipart values 0/7/3650, Escape cancellation without an attachment request, picker focus, phone width and a scoped WCAG accessibility scan. Public-page tests cover the storage explanation, entry link and width without an API.
- Refreshed the board date, current reports and the remaining-input handoff. Removed the obsolete question asking whether 180 days means active-file expiry: the owner's explicit upload choices are already implemented.

## Protected prerequisite check

Read-only checks on 9 November reconciled the original owner-input hash successfully. The five application secret validations pass. TURN signing configuration is present. AI provider and Google/Microsoft contacts OAuth file groups are absent. No credential values are included here.

The immutable-image release configuration and database CA are missing. Cloud/DNS delegation has not been supplied. No external service was contacted, no deployment was activated and no paid provider call was made. The budget calculator uses historical planning assumptions; its output is not a current quote.

## Engineering execution after delegation

1. Use protected cloud, DNS and registry access to provision staging and private storage/scanning. Record actual endpoints, trusted database CA, immutable image digests and deployment identity. Validate configuration with `python infrastructure/preflight_release.py infrastructure/release.json`.
2. Configure approved provider projects, controlled recipients, OAuth callbacks, AI limits and TURN. Execute [the acceptance scenarios](ACCEPTANCE-EXECUTION-PACK-2026-11-08.md) for real delivery, calling and health processing.
3. Run exact-release access isolation, expiry/deletion, responsive/accessibility, capacity, restore and alert/rollback checks. Record results against [every website gate](WEBSITE-LAUNCH-2026-11-09.md). Do not reuse local fixtures as live evidence.
4. Obtain reviewed public policies, delivery verification for the owner-designated Help@myaaptha.com mailbox, live acceptance of the confirmed 90-day deleted-version recovery policy, independent security/health-quality acceptance and final owner release approval. Promote only the accepted immutable artifacts using the [deployment handoff](../MYAAPTHA-DEPLOYMENT-HANDOFF.md).

Engineering owns setup and tests; the owner supplies delegated account access and business approvals. Native signing/store work remains separate. The historical 9 November target is not a confirmed launch date.

## Verification

Six focused desktop/phone browser checks passed, including the expiry-dialog accessibility scan. A clean production build passed (existing lint warnings remain). All 14 production desktop/phone browser tests passed, including CSP injection blocking and nonce rotation, and all 23 web unit tests passed. All 82 infrastructure tests passed. Hosted board verification passed with zero browser errors, including source refresh, saved-plan preservation, acceptance guards and 390 px layouts. The first local test runner lingered after its six passing cases; an overlapping build disrupted that development cache. Both runners were stopped, the generated cache was rebuilt cleanly, and the reported production results come from the subsequent isolated run. No live API/provider/device acceptance is claimed. The most recent previously verified application CI is [the 8 November run](https://github.com/SreeS31/MyAaptha/actions/runs/42457704226); it does not certify today's changes or authorize deployment.

Local production browser and unit output is retained in `.tools/launch-board/production-web-tests-2026-11-09.log` and `.tools/launch-board/web-unit-tests-2026-11-09.log`. These ignored logs do not contain provider credentials.

## Owner contact update

The owner supplied **Help@myaaptha.com** for both support and privacy. Added to the public landing page, signed-in privacy settings and review drafts. Original October answers/hash remain preserved with a dated decision addendum. Mailbox delivery has not been tested; no email was sent and no DNS/mailbox changes were made. Policy approval and M18.3 remain open.

Contact-update verification: TypeScript `tsc --noEmit`, nine owner-input regression tests, hosted board verification (zero browser errors) and `git diff --check` passed.

## Pending-work continuation: native contact parity

Confirmed the previous contact/web commit `58208e2` passed [GitHub CI](https://github.com/SreeS31/MyAaptha/actions/runs/42597783127). The owner-input snapshot still reconciles; protected application and TURN groups are present, AI and contacts-OAuth groups remain absent. No new cloud/DNS delegation was supplied.

Added the same Help@myaaptha.com contact to native settings and Help, with selectable text, a copy button and accessible success/failure feedback. The contact is independent of the Help/settings API response, so it remains available during service failures. No email is sent by these controls. This source change does not rebuild or certify a signed mobile release.

Continuation verification: five focused Flutter tests passed, including copying the address with a failed Help API and settings at 320 px with 1x/2x text. One existing Help test initially scrolled its switch under the toolbar after the new card changed content height; it now scrolls to a hit-testable switch before exercising opt-in. Hosted board verification passed with zero browser errors; web/native public-contact strings match the owner input.

Targeted Flutter static analysis of all four changed Dart files passed with no issues. `git diff --check` passed. The SDK initially required normal cache/tool-state access before tests could start; the reported results are from the subsequent successful run.

## Deleted-file recovery decision

Owner confirmed 90 days. Recorded the dated addendum and prepared noncurrent-only S3 lifecycle/versioning templates. Updated M14.6 and remaining-input handoff; no cloud changes or recovery acceptance are claimed. See [policy and implementation boundaries](RECOVERY-POLICY-2026-11-09.md).

Recovery-policy verification: all 85 infrastructure tests passed, including three new lifecycle/owner-contract guards. Hosted board verification passed with zero browser errors. Active-file options/Never remain unchanged; no live cloud lifecycle was applied.

## Google Cloud beta authorization

Owner approved Google Cloud trial for beta. Prepared [the reviewed provisioning and application handoff](GCP-BETA-2026-11-09.md), a no-network plan generator and a separate scan-gated beta image workflow. No local Google Cloud authentication/configuration, Project ID or delegated access was found. Account activation and actual deployment are pending; no cloud resources, paid-billing upgrade, production DNS or production data were changed.

Beta-preparation verification: all 90 infrastructure tests passed, including project isolation, no-public-database/storage ports, IAP-only SSH, retained disk/non-destructive stop, shell rendering and CI/scan-gated beta image publication checks. Hosted board verification passed with zero browser errors. The generator produced a local fixture bundle without contacting cloud services. No authenticated cloud provisioning or full application deployment was tested.
