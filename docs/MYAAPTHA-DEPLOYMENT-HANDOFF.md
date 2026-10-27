# MyAaptha deployment handoff

Prepared: 6 September 2026

## Current decision

The full PostgreSQL application is the release target. Its source is now in the main repository at backend/spring-boot-app, frontend/nextjs-app, ai/agent-service and mobile/flutter-app. The original linked integration worktree and smaller MySQL scaffold have been preserved. Do not deploy the MySQL scaffold.

This document separates implemented preparation from things that require your accounts, decisions or external validation. Dummy values are provided for planning only; production startup and release rendering reject known placeholders.

## What you need to provide later

| Item | What to provide or decide | Dummy value / current handling | Required before |
| --- | --- | --- | --- |
| Cloud account | Provider, account/project/subscription, billing owner, deployment identity and permitted region | Provider undecided; ap-south-1 is a template region only | Provisioning |
| Capacity and budget | Expected active/concurrent users, upload volumes, monthly budget and availability target | Templates start with two Kubernetes application replicas; capacity is unverified | Sizing and launch |
| Domain and DNS | Your domain, DNS access, final public web/API address | app.example.com; same-origin /api routing | Public staging |
| Database | Managed PostgreSQL 17 host, database, user, private network, CA certificate and backup policy | managed-postgres.example.internal; database myaaptha | Staging |
| Database password | Random production password, at least 16 characters, placed in the secret manager | No production password generated or committed | Staging |
| JWT signing secret | Cryptographically random secret of at least 32 bytes and rotation owner | Placeholder rejected; temporary test keys are not production keys | Staging |
| File storage | Private S3-compatible bucket, region, workload role and optional endpoint | replace-with-private-bucket | Upload testing |
| TLS and ingress | Certificate, ingress controller, controller namespace and firewall rules | nginx / ingress-nginx; myaaptha-tls secret | Public staging |
| Image registry | Registry owner, repository permissions and private-image pull credentials if needed | ghcr.io/OWNER; release outputs immutable image digests | Image publication |
| Release governance | Reviewed release commit, branch/tag protection, required CI checks and deployment operator | Workflows prepared; remote repository settings not inspected or changed | Production promotion |
| AI health reports | Provider account/API key, billing limit, approved model and permission to process health reports | OPENAI_API_KEY absent; feature unavailable until configured | Enabling health report analysis |
| Google/Microsoft contacts | OAuth client IDs/secrets, approved scopes and verified redirect domains | Optional; no fake provider credentials enabled | Enabling contact import |
| Email/SMS/push | Provider choice, verified sender/domain, webhook URL/token and push platform credentials | Optional channels disabled until real configuration | Enabling notifications |
| Account verification | Agreed phone/email verification and account recovery workflow; provider credentials | Existing registration is not proof of phone ownership. Unverified invitation claiming is now blocked; verified claiming needs a real workflow | Public registration |
| Monitoring | Alert recipients/on-call owner, logs/metrics provider, retention and cost alerts | Alert requirements documented; no live delivery configured | Production |
| Privacy and support | Entity/contact details, support address, privacy notice, terms, consent for health/contact processing, deletion and retention policy | Do not publish dummy contact or policy details | Public launch |
| Security review | Independent staging penetration test and review of authorization, uploads, sessions and integrations | Automated checks help but do not replace this review | Production |
| Performance acceptance | Agreed p95/p99 latency and concurrency targets, representative staging load test | Historical local report missed proposed latency targets; no production SLA claimed | Production |
| Recovery acceptance | Backup/PITR settings, retention, RPO/RTO targets and a recorded restore drill | Restore procedure prepared; production backup service not provisioned | Production |
| Android release (if included) | Final application ID, signing keystore/passwords, Play account, store assets and privacy declarations | No production signing key included | Store submission |
| iOS release (if included) | Bundle ID, Apple team, certificates/profiles, App Store account and privacy declarations | No signed iOS archive supplied | Store submission |

Store secrets in your cloud secret manager or protected CI environment, not in this document, source files, chat or email. Non-secret deployment values belong in the ignored infrastructure/release.json file. For optional backend integrations, add the exact keys below to myaaptha-secrets (Kubernetes) or explicitly map secret files through Spring configuration (Compose).

## Configuration reference

Required: REDIS_HOST, REDIS_PASSWORD, REDIS_PORT (6379), REDIS_TLS (true), POSTGRES_HOST, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, JWT_SECRET, MYAAPTHA_S3_BUCKET, MYAAPTHA_S3_REGION, MYAAPTHA_CORS_ALLOWED_ORIGINS, MYAAPTHA_PUBLIC_API_BASE_URL, MYAAPTHA_WEB_ORIGIN.

Optional: MYAAPTHA_S3_ENDPOINT, OPENAI_API_KEY, OPENAI_MODEL, GOOGLE_CONTACTS_CLIENT_ID, GOOGLE_CONTACTS_CLIENT_SECRET, MICROSOFT_CONTACTS_CLIENT_ID, MICROSOFT_CONTACTS_CLIENT_SECRET, MYAAPTHA_NOTIFICATION_WEBHOOK_CHANNEL, MYAAPTHA_NOTIFICATION_WEBHOOK_URL, MYAAPTHA_NOTIFICATION_WEBHOOK_TOKEN.

OAuth redirects use the actual callback routes in the backend; register those precise paths with the providers after selecting the domain. Mobile builds require PRODUCTION_API_URL / API_BASE_URL with the final HTTPS API base URL, using the existing client convention.

Database TLS defaults to verify-full. A temporary isolated local database test may use disable; do not copy that override to production. Configure the provider CA certificate in the application and migration Job when required.

## Prepared in the repository

- Canonical full application source restored to root application directories; release no longer depends on the linked worktree.
- Global administration APIs restricted to administrators, while member APIs remain separately scoped.
- Production validation rejects known dummy credentials, invalid public origins, local storage and automatic schema mutation.
- HTTPS public web/API settings wired into CORS, storage and OAuth configuration.
- Frontend container API routing configured at build time; release uses same-origin public API routes.
- Container users use explicit non-root numeric identities; writable temporary/cache paths are separated.
- Kubernetes AI image name corrected; readiness, liveness and startup probes separated; disruption budgets, ingress and inbound network policies provided.
- One-off Flyway migration task gates rollout; application replicas validate the schema rather than modifying it.
- Production Compose uses managed external database/storage and publishes only the gateway ports.
- CI and tagged image publishing gated by tests and vulnerability checks; SBOM and digest artifacts retained.
- Non-secret release renderer rejects example values and mutable image tags; deployment script stops after migration failure.
- Backup checksum generation and non-destructive empty-database restore procedure prepared.

## Operational work still requiring execution

Provisioning accounts and services, attaching cloud identities, DNS/TLS validation, remote CI execution, container publication, cloud rollout, notification delivery, provider OAuth verification, signing/store submission, independent security/privacy reviews, realistic load testing and the production disaster-recovery drill remain external launch gates. These cannot be completed with dummy data.

The application stores sensitive personal, finance and health information. Validate consent and deletion behavior with realistic staging accounts. Confirm phone ownership before allowing an invitation to be claimed. Security-sensitive third-party workflows must stay disabled until their real verification is implemented and tested.

## Deployment sequence

1. Review and commit the canonical source. Confirm a clean checkout builds without the local integration worktree.
2. Run required CI and security checks, then publish a reviewed release tag.
3. Fill infrastructure/release.json from infrastructure/release.example.json using real non-secret values and scanned image digests.
4. Provision private database/storage, identities, secrets, TLS, ingress and monitoring.
5. Restore sample/backup data into staging and run infrastructure/deploy.ps1 with the explicit staging context.
6. Verify migrations, login/session lifecycle, cross-user isolation, circles, uploads, health/finance, messaging and enabled providers.
7. Finish security, privacy, load and recovery acceptance. Record results and release approval.
8. Roll out production with the reviewed config and retain the previous image digests for rollback.

See docs/cloud-deployment.md for commands, limitations and rollback details. See docs/deployment-validation.md for the actual local verification results and remaining technical checks.

## Cloud and AI recommendation

Start by evaluating AWS ECS/Fargate + RDS PostgreSQL + private S3, with OpenAI API for application automation. Current templates target Kubernetes/Compose; ECS infrastructure remains a follow-up once AWS is selected. Compare OpenAI, Claude and Gemini on your actual tasks before finalizing models. See docs/cloud-and-ai-recommendation.md for sources, growth planning, privacy and cost controls. Registration count alone does not establish concurrency or required infrastructure size.

## Scaling release: additional inputs and acceptance

| Item | You must supply or arrange | Current development value |
| --- | --- | --- |
| Managed Redis | Private endpoint, strong secret, TLS, failover; cluster mode disabled; no-eviction policy and memory alarms | Placeholder host; real disposable Redis used only for tests |
| Traffic expectations | Peak simultaneous active users, requests per second, average attachment size, AI jobs per minute, group sizes | Planning assumption: one million registered users; not one million concurrent sessions |
| Database budget | Provider connection limit, reserved connections and instance size | Pool 20 per API; max 10 API replicas plus one rollout surge; reserve 40; minimum budget 260 |
| Load acceptance | Staging account and permission to provision representative infrastructure and run sustained traffic | Local synthetic-data validation; see scaling-readiness.md |
| Operations | Alert recipients, availability target, backup retention, recovery-time and recovery-point objectives | Must be completed before public launch |
| Delivery provider | Provider must honor Idempotency-Key for webhook retries | Dummy provider disabled; no real messages sent |

Migrations V52 and V53 add scaling indexes, delivery leases and scheduler locks. Run the one-off migration before application rollout. Index creation is transactional and can block writes on a large existing table; schedule a maintenance window and assess concurrent index creation before migrating a busy production database. Do not replace production secrets with the test values from CI.

The application has new scaling safeguards; this document does not certify million-user traffic capacity. Review the measured results and remaining workload-specific work in scaling-readiness.md before approving a production scale target.

## Latest security decision

Public production security approval is pending. See scaling-readiness.docx for the full review and required identity verification, browser-session hardening, malware scanning, edge protection, penetration testing and cloud load-test evidence. Also supply TRUSTED_PROXY_REGEX using only actual ingress/frontend proxy addresses.
