# Inputs needed from the project owner - 22 October 2026

You supply access, account references and business decisions. Development, integration, synthetic fixtures, automated testing, failure diagnosis and remediation stay with engineering. You do not need to test each module or confirm all 29 tasks individually. Shared inputs unlock multiple tasks.

| Priority | Input to supply | Engineering work it unlocks |
|---|---|---|
| 1 | Existing server/cloud provider and project, region, staging domain/DNS access reference, registry namespace, deployment identity and approved spending limit. If none is selected, say so and give the allowed budget/region. | Staging provisioning, exact-release account/messaging/finance/browser acceptance, capacity tests and security-review environment. |
| 2 | Database/Redis service references and provider CA; private storage bucket, region and workload/IAM identity; backup/PITR service; approved current/noncurrent-version retention, deletion and recovery requirements. Use secret-manager references for credentials. | Real infrastructure connectivity, storage privacy/encryption/scanning, lifecycle and DB/media recovery tests. |
| 3 | SMS/email/push provider account references, approved sender identities, challenge configuration and controlled test recipient/device-token references; monitoring/alert destination and on-call owner. | Registration/recovery, emergency/general/security delivery, retry/deduplication and alert acknowledgement tests. |
| 4 | Google/Microsoft app-registration references, allowed consent scopes and registered callbacks for the selected staging domain. | Real consent/import/cancellation tests and shared routing acceptance. |
| 5 | AI provider configuration reference, approved model candidates, spending limit and permitted test data; named reviewer for answer quality and health-processing policy. | Provider readiness, budget/data-policy checks, model evaluation and health enablement review. |
| 6 | Controlled Android/iOS devices; final Android application ID and iOS bundle ID; Play/Apple account/team references, Android signing-key reference/public certificate fingerprint and macOS/Xcode runner/provisioning references. Confirm whether calling is launch scope and supply any required relay-service configuration reference. | Physical-device permissions/lifecycle/calling tests, signed Android/iOS candidates and store validation. Submission retains owner approval. |
| 7 | Legal entity/contact, privacy/support contact, named moderation/support operators, approved privacy/terms/health/emergency-document policies, independent security reviewer and final release approver. | Operating-role rehearsals, review remediation and exact production release sign-off. Engineering cannot provide independent approval of its own work. |

## Reply template

1. Hosting/project, region, domain and budget:
2. Database/cache/storage/backup references and retention requirements:
3. Notification providers, test recipients and alert owner:
4. Google/Microsoft registrations:
5. AI configuration, models and test spending limit:
6. Devices, app IDs, store/signing references and Mac runner:
7. Legal/support/moderation owners, reviewer and release approver:

Send items in stages if needed; hosting is the first shared dependency. Provide existing signing references if available; otherwise engineering can prepare signing material and a protected owner handoff once the store identity and final app IDs are established. Keep passwords, API secrets, private keys and signed access URLs out of chat. Store them through protected local configuration or your approved secret manager and share only their references. Existing example configuration is not evidence that a production account or environment is provisioned.

Local engineering evidence is recorded in the [web/form review](WEB-UX-REVIEW-2026-10-21.md), [operational verification](OPERATIONAL-METRICS-2026-10-20.md), [release preflight](RELEASE-PREFLIGHT-2026-10-20.md) and [storage recovery drill](S3-RECOVERY-2026-10-21.md). The [complete 29-task acceptance audit](PENDING-ACCEPTANCE-2026-10-24.md) maps every remaining requirement to its task. Current closure count is 61/90 (24 October refresh); local checks do not substitute for real delivery, physical devices, independent approval or a selected production environment.
