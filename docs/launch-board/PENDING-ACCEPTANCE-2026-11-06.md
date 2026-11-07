# Remaining launch acceptance - 2026-11-06

Every currently pending source task is listed below. Local implementation and launch acceptance are separate; this report does not grant external approvals.

## Staging environment (7)

| Task / accountable team | Required to complete | Next action |
|---|---|---|
| M01.5 Release account-security regression (Backend / Security) | Selected release URL/digests and provider-backed account fixtures | Run login, refresh, logout, recovery and isolation against that release. |
| M06.4 Staging membership and removed-member access regression (Messaging) | Selected staging build and disposable membership fixtures | Run removed-member history, search and attachment denial on staging. |
| M07.6 Release read/delete race and cross-client regression (Messaging) | Selected staging build and two real client/device sessions | Run concurrent read/delete and cross-client redaction checks. |
| M10.4 Release import and time-boundary acceptance (Finance) | Selected staging build and representative sanitized import fixtures | Verify import deduplication and UTC boundary outcomes on staging. |
| M15.4 Provision staging cloud, DNS, TLS, secrets and registry (DevOps) | Actual cloud/project deployment delegation, registry access, issued TLS certificates and DNS administration. India region, domain and budgets have been received. | Use the prepared profiles and protected application secrets; provision staging after real account access, then record its endpoint and image digests. |
| M15.5 Repeat capacity acceptance on representative infrastructure (DevOps) | Representative staging resources, load-generator capacity and target workload | Run the agreed capacity profile and accept measured error/latency limits. |
| M16.6 Rerun exact-release cookie/bearer and accessibility suite (QA / Mobile) | Selected staging release with exact image/build identities | Run cookie, bearer, responsive and accessibility acceptance on those artifacts. |

## Provider and model validation (7)

| Task / accountable team | Required to complete | Next action |
|---|---|---|
| M01.4 Validate real verification / recovery delivery (Backend / Security) | SMS/verification provider, approved sender, challenge configuration and test recipients | Verify real registration/recovery delivery and ownership end to end. |
| M04.4 Activate Google / Microsoft OAuth in staging (Integrations) | Google/Microsoft registrations, exact callbacks, approved scopes and configured secret references | Verify real provider consent, import review, cancellation and shared routing on staging. |
| M11.3 Validate owner emergency alert delivery (Trust / Security) | Approved emergency alert channels and controlled recipient/device fixtures | Deliver a real emergency notification and verify owner receipt. |
| M12.5 Set provider secrets, budget alerts and data policy (AI / Backend) | Production AI secret references, enforced spend limits/alerts and approved processing policy. INR 3,000/month budget has been received. | Configure provider access and hard spend controls, then validate processing policy and provider readiness. |
| M12.6 Evaluate stronger model before enabling retries (AI / Backend) | Approved model candidates, evaluation budget and named quality reviewer | Collect representative model answers, score the rubric and approve or reject retries. |
| M13.3 Configure and prove real email/SMS/push delivery (Integrations) | Email/SMS/push providers, sender identities, callbacks and test device tokens | Verify actual delivery, failure handling, retry and deduplication. |
| M13.4 Validate security-alert delivery and on-call route (Integrations) | Security-alert recipient, provider route and on-call owner | Trigger a controlled security alert and record delivery and acknowledgement. |

## Devices and distribution (5)

| Task / accountable team | Required to complete | Next action |
|---|---|---|
| M04.5 Validate device contacts permissions (Integrations) | Physical Android/iOS access with OS permission and revocation coverage | Validate denied/limited/full permissions and selected-contact persistence on devices. |
| M07.5 Validate real-device calling / network behavior (Messaging) | Calling scope decision and physical devices on representative networks | Validate permission, connectivity, audio/video and network changes if calling is included. |
| M16.3 Physical Android/iOS acceptance and native parity review (QA / Mobile) | Physical Android/iOS devices and an agreed acceptance matrix | Execute important flows, permissions, lifecycle and native parity acceptance. |
| M16.4 Android production signing and store submission (QA / Mobile) | Final application ID, owner upload key, Play identity and approved disclosures | Build with the owner signing identity, verify its fingerprint and complete store submission. |
| M16.5 iOS archive, signing and App Store submission (QA / Mobile) | macOS/Xcode runner, Apple team, final bundle ID, signing profiles and store disclosures | Archive, sign, validate on devices and complete App Store submission. |

## Policy and independent review (5)

| Task / accountable team | Required to complete | Next action |
|---|---|---|
| M08.4 Launch content/abuse operating policy (Social) | Named moderation staff, approved policy, escalation and appeal routes | Approve the operating policy and rehearse real moderation roles. |
| M09.4 Enable health analysis only after provider/consent validation (Health / Privacy) | Approved health processing/consent policy, provider quality and spend acceptance | Complete provider quality/privacy review and controlled device acceptance before enablement. |
| M11.4 Approve sensitive-document emergency policy (Trust / Security) | Policy owner approval for eligible emergency documents, retention and access windows | Approve the sensitive-document policy and verify operating/audit procedures. |
| M18.3 Approve privacy, terms, consent, support and moderation owners (Product / Security / Owner) | Reachable policy/support contact details, completed policies and recorded review approvals. CPET Solutions Pvt. Ltd., India, manager/CTO responsibilities and release approver have been received. | Complete privacy, terms, consent, retention and moderation documents with designated owners; record independent review and release approval. |
| M18.4 Independent staging security review and remediation acceptance (Product / Security / Owner) | Selected staging build and an independent security reviewer | Perform independent account/upload/integration testing and accept remediation. |

## Production operations (5)

| Task / accountable team | Required to complete | Next action |
|---|---|---|
| M14.5 Provision private storage and production scanner (Platform / Security) | Approved private bucket/IAM/encryption and production antivirus infrastructure | Verify private storage, scanner pinning, signatures and monitoring on the selected platform. |
| M14.6 Validate retention, object deletion and media recovery (Platform / Security) | Actual storage lifecycle/recovery setup and isolated synthetic object fixtures; clarification of whether 180 days means active-file expiry or deleted-version recovery. | Keep existing retention unchanged until clarified; verify deletion/version behavior and media restoration against actual storage without customer data. |
| M15.6 Record production-like backup/PITR restore drill (DevOps) | Managed database/PITR and media backups plus an isolated recovery environment | Measure representative DB/media recovery, integrity, RPO and RTO. |
| M15.7 Activate monitoring, alert routes and rollback rehearsal (DevOps) | Selected runtime, monitoring system, alert recipients and rollout identity | Activate alerts and execute a reviewed rollback rehearsal with recovery timestamps. |
| M15.8 Approve exact release artifact and production promotion (DevOps) | Immutable production digests, signing/scans, accepted prerequisites and named approver | Review the exact release evidence and record production promotion approval. |
