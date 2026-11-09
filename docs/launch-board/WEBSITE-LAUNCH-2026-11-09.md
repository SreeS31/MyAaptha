# Website launch requirements - 2026-11-09

26 open acceptance tasks apply to the website. 3 additional tasks apply only to native app distribution/permissions. The overall board remains unchanged; separating scope does not approve any task.

Health analysis and audio/video calling remain required owner scope. Browser calling, responsive phone-browser checks, cross-client behavior and real-device/network checks remain website requirements.

## Execution order

1. Deployment access: delegate the cloud/project, registry and DNS through protected access references. Engineering then provisions staging, records immutable image identities and installs the database CA. No new deployment access has been supplied.
2. Real services: supply approved email/SMS/push, OAuth, AI and TURN configuration and controlled test recipients. Engineering runs delivery, recovery, calling and model acceptance.
3. Operating decisions: verify delivery to the owner-designated support/privacy mailbox Help@myaaptha.com, approve reviewed consent/moderation/emergency policies and the deleted-version recovery duration. Active-file expiry choices are already implemented; Never remains available.
4. Release acceptance: engineering runs staging isolation, capacity, accessibility, storage lifecycle, restore and monitoring drills. An independent reviewer completes security acceptance; the owner approves the measured release before promotion.

The latest protected local preflight found all five application secret files valid. It still lacks a real immutable-image release configuration and database CA. Local secrets do not establish cloud or provider access.

Latest synchronized storage implementation and regression tests passed all nine CI jobs: [verified run](https://github.com/SreeS31/MyAaptha/actions/runs/42457704226). This does not substitute for live acceptance.

## Website requirements

| Task | Required input/evidence | Engineering next action |
|---|---|---|
| M01.5 Release account-security regression | Selected release URL/digests and provider-backed account fixtures | Run login, refresh, logout, recovery and isolation against that release. |
| M06.4 Staging membership and removed-member access regression | Selected staging build and disposable membership fixtures | Run removed-member history, search and attachment denial on staging. |
| M07.6 Release read/delete race and cross-client regression | Selected staging build and two real client/device sessions | Run concurrent read/delete and cross-client redaction checks. |
| M10.4 Release import and time-boundary acceptance | Selected staging build and representative sanitized import fixtures | Verify import deduplication and UTC boundary outcomes on staging. |
| M15.4 Provision staging cloud, DNS, TLS, secrets and registry | Actual cloud/project deployment delegation, registry access, issued TLS certificates and DNS administration. India region, domain and budgets have been received. | Use the prepared profiles and protected application secrets; provision staging after real account access, then record its endpoint and image digests. |
| M15.5 Repeat capacity acceptance on representative infrastructure | Representative staging resources, load-generator capacity and target workload | Run the agreed capacity profile and accept measured error/latency limits. |
| M16.6 Rerun exact-release cookie/bearer and accessibility suite | Selected staging release with exact image/build identities | Run cookie, bearer, responsive and accessibility acceptance on those artifacts. |
| M01.4 Validate real verification / recovery delivery | SMS/verification provider, approved sender, challenge configuration and test recipients | Verify real registration/recovery delivery and ownership end to end. |
| M04.4 Activate Google / Microsoft OAuth in staging | Google/Microsoft registrations, exact callbacks, approved scopes and configured secret references | Verify real provider consent, import review, cancellation and shared routing on staging. |
| M11.3 Validate owner emergency alert delivery | Approved emergency alert channels and controlled recipient/device fixtures | Deliver a real emergency notification and verify owner receipt. |
| M12.5 Set provider secrets, budget alerts and data policy | Production AI secret references, enforced spend limits/alerts and approved processing policy. INR 3,000/month budget has been received. | Configure provider access and hard spend controls, then validate processing policy and provider readiness. |
| M12.6 Evaluate stronger model before enabling retries | Approved model candidates, evaluation budget and named quality reviewer | Collect representative model answers, score the rubric and approve or reject retries. |
| M13.3 Configure and prove real email/SMS/push delivery | Email/SMS/push providers, sender identities, callbacks and test device tokens | Verify actual delivery, failure handling, retry and deduplication. |
| M13.4 Validate security-alert delivery and on-call route | Security-alert recipient, provider route and on-call owner | Trigger a controlled security alert and record delivery and acknowledgement. |
| M07.5 Validate real-device calling / network behavior | Physical Android/iOS devices, representative networks and a deployed authenticated TURN relay; audio and video calling are confirmed launch requirements. | Validate both audio and video calling, permissions, relay transport, reconnects and network changes on physical devices. |
| M16.3 Physical Android/iOS acceptance and native parity review | Physical Android/iOS devices and an agreed acceptance matrix | Execute important flows, permissions, lifecycle and native parity acceptance. |
| M08.4 Launch content/abuse operating policy | Named moderation staff, approved policy, escalation and appeal routes | Approve the operating policy and rehearse real moderation roles. |
| M09.4 Enable health analysis only after provider/consent validation | Approved health processing/consent policy, provider quality and spend acceptance | Complete provider quality/privacy review and controlled device acceptance before enablement. |
| M11.4 Approve sensitive-document emergency policy | Policy owner approval for eligible emergency documents, retention and access windows | Approve the sensitive-document policy and verify operating/audit procedures. |
| M18.3 Approve privacy, terms, consent, support and moderation owners | Owner supplied Help@myaaptha.com for support and privacy. Verify mailbox reachability and ownership; final reviewed policies and actual owner approvals remain required. | Complete privacy, terms, consent, retention and moderation documents with designated owners; record independent review and release approval. |
| M18.4 Independent staging security review and remediation acceptance | Selected staging build and an independent security reviewer | Perform independent account/upload/integration testing and accept remediation. |
| M14.5 Provision private storage and production scanner | Approved private bucket/IAM/encryption and production antivirus infrastructure | Verify private storage, scanner pinning, signatures and monitoring on the selected platform. |
| M14.6 Validate retention, object deletion and media recovery | Actual storage lifecycle/recovery setup and isolated synthetic fixtures; defined deleted-version recovery duration. Uploaders choose expiry or Never; 1 GB initially and paid plans up to 100 GB. | Verify selected expiry denial and deletion, Never retention, quota preservation, explicit user deletion and restoration on actual storage without customer data. |
| M15.6 Record production-like backup/PITR restore drill | Managed database/PITR and media backups plus an isolated recovery environment | Measure representative DB/media recovery, integrity, RPO and RTO. |
| M15.7 Activate monitoring, alert routes and rollback rehearsal | Selected runtime, monitoring system, alert recipients and rollout identity | Activate alerts and execute a reviewed rollback rehearsal with recovery timestamps. |
| M15.8 Approve exact release artifact and production promotion | Immutable production digests, signing/scans, accepted prerequisites and named approver | Review the exact release evidence and record production promotion approval. |

## Native-only requirements

| Task | Required input/evidence | Engineering next action |
|---|---|---|
| M04.5 Validate device contacts permissions | Physical Android/iOS access with OS permission and revocation coverage | Validate denied/limited/full permissions and selected-contact persistence on devices. |
| M16.4 Android production signing and store submission | Final application ID, owner upload key, Play identity and approved disclosures | Build with the owner signing identity, verify its fingerprint and complete store submission. |
| M16.5 iOS archive, signing and App Store submission | macOS/Xcode runner, Apple team, final bundle ID, signing profiles and store disclosures | Archive, sign, validate on devices and complete App Store submission. |

