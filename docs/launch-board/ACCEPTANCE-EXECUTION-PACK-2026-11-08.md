# Pending-task execution pack - 8 November 2026

Status: preparation for the 29 pending launch gates. This document is not an approval or a substitute for running the checks on the selected release. The confirmed scope includes health analysis, audio calls and video calls. No task was closed by preparing this pack.

## Evidence recorded for every execution

Record the task ID, operator/reviewer, timestamp with timezone, environment URL, source commit, immutable API/web/AI image digests, native build ID and signing fingerprint where relevant, device/OS/network, synthetic fixture identifiers, expected/actual outcome, redacted evidence location, cleanup outcome and remaining defects. Keep credentials, tokens, private contact data and signing material out of source control and screenshots. A successful local fixture is not evidence for a different staging or production artifact.

Execution results begin as **not run**. A failing or skipped scenario remains open. Required independent/owner approvals must identify the actual reviewer and selected artifacts. Engineering can execute tests; it cannot supply another person's acceptance.

## Environment and accounts

| Gate | Execution and pass criteria |
|---|---|
| M15.4 Staging provisioning | With delegated access, provision the selected India-region runtime, private DB/cache, trusted TLS and exact registry images. Verify public web/API origin, private service isolation, certificate validation and provider-secret injection. Record endpoints and immutable digests. |
| M01.4 Registration/recovery delivery | Use controlled recipients with the approved SMS/challenge provider. Verify actual receipt, invalid/expired/replayed codes, throttling and recovery ownership. Confirm old sessions are revoked as designed. |
| M01.5 Release account security | On the selected release, exercise cookie and bearer login, refresh concurrency, logout, recovery and cross-account denial. Record both success and rejection results using provider-backed fixtures. |
| M04.4 OAuth contacts | Complete real Google and Microsoft consent using registered exact callbacks/scopes. Verify cancellation, denied scopes, replay/state rejection, selected import review, duplicate handling and cross-account isolation. |
| M06.4 Removed membership | With two synthetic accounts, remove membership while the second session is active. History, search and attachment requests must be denied consistently after removal; reconnect must not restore access. |
| M07.6 Read/delete races | Use two clients of the selected build. Concurrently read/delete messages and attachments; refresh/reconnect both. Verify redaction converges and unauthorized clients cannot recover deleted content. |
| M10.4 Imports/time boundaries | Use sanitized representative imports, repeated imports, month-end/year-end/leap-day timestamps and two owners. Verify totals, UTC boundaries, deduplication and ownership against expected fixture values. |
| M16.6 Exact-release web acceptance | Run cookie/bearer flows, responsive keyboard/accessibility checks and upload/security checks against the recorded image/build identities. Keep results tied to those identities. |

## Physical clients and distribution

Use physical Android and iOS devices. Record OS/model and test denied, limited and granted permissions; background/foreground; process termination; offline/reconnect; and revoked permissions. Emulator/widget results do not complete these gates.

| Gate | Execution and pass criteria |
|---|---|
| M04.5 Device contacts | Verify denied/limited/full contact access, selection review, persistence, cancellation and revocation on both platforms. Import only selected synthetic contacts. |
| M07.5 Audio and video calls | Both modes are required. Test Android/Android, iOS/iOS and cross-platform pairs on Wi-Fi and mobile networks. Verify microphone/camera refusal, cancellation, background interruption, reconnect, Wi-Fi/mobile changes, relay-only connectivity, remote end and resource release. Record authenticated TURN transport evidence without credentials. |
| M16.3 Native parity | Check registration/recovery, profile/gallery, relationships, contacts, messaging/attachments, calls, timeline, finance/renewals, notifications, consented health processing, trust/emergency flows and account settings against the same API release. Record every discrepancy. |
| M16.4 Android release | Use the approved application ID and owner upload key. Verify release signing fingerprint, install/upgrade and device flows, then prepare approved store disclosures and submit through the owner's Play identity. Debug signing does not qualify. |
| M16.5 iOS release | Use macOS/Xcode, the owner's Apple team and approved bundle ID/profiles. Archive, validate signing/entitlements, run physical-device acceptance and complete the approved store submission. |

## Providers, policy and review

These are operational review instructions, not legal advice or approved public policy text. The existing content-operations and health-consent drafts remain review material. Public contacts must be reachable before publication. The owner has not clarified whether 180 days means active-file expiry or deleted-file recovery; automatic deletion remains unchanged.

| Gate | Execution and pass criteria |
|---|---|
| M08.4 Moderation operations | The CTO-designated team reviews the content-operations draft, names staffed moderation/escalation/appeal routes, and rehearses reporting, review, decisions and appeals using synthetic cases. Record reviewer acceptance. |
| M09.4 Health activation | Privacy/quality reviewers accept the processing disclosure, provider handling, explicit per-report consent, extraction quality, deletion guidance and budget controls. Use synthetic consented reports on real devices. Enable only after acceptance; verify disabled/missing-consent paths still refuse processing. |
| M11.4 Emergency documents | The CTO-designated owner decides eligible documents, access windows, retention and authorized recipients. Rehearse authorization, expiry, revocation and audit review before acceptance. |
| M18.3 Public policies/owners | The Manager-designated privacy/support owner supplies reachable contacts and reviewed privacy/terms/consent/retention text. CTO confirms moderation ownership. Record actual review and owner release decisions; company/role names alone are not approvals. |
| M12.5 AI configuration | Configure protected provider references, the approved INR 3,000/month controls and alert recipients. Verify actual limits/alerts and approved processing handling; an application feature flag is not a provider spend cap. |
| M12.6 Model evaluation | With approved candidates, budget and quality reviewer, collect representative answers and score the existing evaluation rubric. Record the reviewed dataset, model IDs, outcomes and decision before enabling retries. |
| M13.3 Notification providers | With verified email/SMS/push identities and controlled recipients/device tokens, test real delivery, invalid destinations, provider failures, retries, duplicates and opt-out behavior. Record receipts without tokens. |
| M11.3 Emergency delivery | Trigger a controlled emergency event through approved channels. Verify actual owner receipt on the intended devices and record the acknowledgement. |
| M13.4 Security/on-call alerts | Trigger a controlled security event, verify delivery to the configured on-call route, acknowledgement, escalation and failure handling. Record the responsible owner. |
| M18.4 Independent security review | An independent reviewer assesses the selected staging artifacts, account isolation, sessions, uploads, integrations and findings. Retest fixes against identified replacement artifacts and record independent remediation acceptance. Automated CI cannot sign this gate. |

## Storage and operations

| Gate | Execution and pass criteria |
|---|---|
| M14.5 Private media/scanner | Verify actual bucket privacy, least-privilege IAM, encryption, signed-read expiry and unauthorized denial. Verify the production scanner identity, freshness enforcement and monitoring, including failure behavior. |
| M14.6 Retention/recovery | After the 180-day meaning is clarified, use isolated synthetic objects on the selected platform. Verify intended deletion/version behavior, lifecycle configuration and recovery byte equality. Measure automatic expiry separately; a configuration round-trip is insufficient. |
| M15.6 Backup/PITR | Restore managed DB/PITR and media backups into an isolated recovery environment. Verify accounts/ownership/schema/media integrity and measure RPO and RTO separately against the provisionally interpreted 24-hour targets. Preserve the source environment. |
| M15.5 Capacity | Run the agreed workload on representative resources with sufficient load generation. Record resource limits, workload, errors and latency against the existing target. The historical failed 5,000-user run is not acceptance. |
| M15.7 Monitoring/rollback | Verify live runtime metrics and actual alert receipt. Rehearse a reviewed rollback with exact prior digests, compatibility checks and measured recovery timestamps. |
| M15.8 Promotion | Assemble immutable artifacts, signing/scans, accepted prerequisite evidence and rollback identity. The project owner reviews that exact release and records a promotion decision. No deployment or approval is inferred from this checklist. |

## Available local preparation commands

Run from the repository root. These checks do not provision cloud services or grant acceptance:

```powershell
python infrastructure/owner_launch_plan.py docs/launch-board/owner-launch-inputs-2026-10-26.json --output .tools/launch-board/owner-readiness-2026-11-08.json
python infrastructure/preflight_release.py infrastructure/release.json
python infrastructure/verify_launch_board.py
```

On 8 November, the owner source snapshot still matches. Read-only preflight with access to protected files passed all five application-secret checks, but failed the release-configuration and database-CA checks. Secret values were not displayed. Keep using protected access references; do not put credentials in this document.
