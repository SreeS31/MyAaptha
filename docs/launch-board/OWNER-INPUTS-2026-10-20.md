# Launch dependencies: who supplies what

20 October 2026. These are missing release inputs or acceptance evidence, not permission requests to continue local development. Coding prerequisites: 68/68 applicable checks; launch acceptance: 60/89 closed, 29 open. Local tests do not certify external delivery or production readiness.

| Input or decision | Supplied by | Work it unlocks |
|---|---|---|
| Existing staging provider/project/server, region, domain, deployment identity and approved budget | Project owner / infrastructure administrator | Provision staging (M15.4), then exact-release account, messaging, finance, transport/accessibility and capacity checks (M01.5, M06.4, M07.6, M10.4, M16.6, M15.5) |
| Approved private storage/scanner, database backup/PITR, monitoring platform and alert recipients | Infrastructure owner | Storage/lifecycle, recovery drills and live alerts/rollback (M14.5, M14.6, M15.6, M15.7) |
| SMS/email/push sender accounts, OAuth registrations/callbacks and controlled recipients | Provider-account owner | Verification/recovery, contact import, emergency/security and general delivery (M01.4, M04.4, M11.3, M13.3, M13.4) |
| AI provider configuration, spending limit, permitted data and named quality reviewer | Product/privacy owner | Budget/data-policy verification and model evaluation (M12.5, M12.6); health enablement additionally requires M09.4 approval |
| Android/iOS test devices; whether calling is launch scope | Product/mobile owner | Permission, calling and native acceptance (M04.5, M07.5, M16.3) |
| Final application IDs, owner Android upload key/Play account; macOS/Xcode runner, Apple team/profiles | Distribution owner | Signed store candidates and submission (M16.4, M16.5) |
| Legal entity/contact, support/moderation owners, approved policies and independent security reviewer | Project/legal/security owners | Moderation, health, emergency-document and policy/security acceptance (M08.4, M09.4, M11.4, M18.3, M18.4) |
| Named release approver after prerequisite evidence is accepted | Release owner | Exact production artifact approval/promotion (M15.8) |

## What development handles

Prepare configuration, implement fixes, run local automated checks, assemble reviewable candidates, update documentation and record accurate board evidence. Once staging access and the approved configuration are available, run its dependent checks and remediate failures. Provider tests use approved controlled recipients. Store submission and production promotion retain explicit owner approval.

## What does not need your confirmation

Routine source changes, local synthetic tests, board/documentation maintenance and safe diagnostics continue within the existing request. An external review cannot be self-approved by the developer who implemented the change. No need to confirm all 29 tasks individually: supply shared dependencies once.

Start with the staging provider/project or server, region, domain and budget. Use secret-manager references or protected local configuration for credentials; do not paste private keys or passwords in chat. If no hosting has been selected, that decision is still needed before paid provisioning.

See the [complete per-task requirements](PENDING-ACCEPTANCE-2026-10-20.md) and [current development evidence](DEVELOPMENT-2026-10-20.md).
