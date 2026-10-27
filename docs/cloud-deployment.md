# MyAaptha cloud release runbook

## Supported source

Use `backend/spring-boot-app`, `frontend/nextjs-app`, `ai/agent-service` and `mobile/flutter-app` from the repository root. The MySQL scaffold and `.integration` worktree are not release inputs.

## Prepare infrastructure

1. Select a cloud account, region and production domain. Provision managed PostgreSQL 17 with private connectivity, TLS, encrypted backups and point-in-time recovery. Use a separate staging database.
2. Provision private S3-compatible storage with encryption, versioning and lifecycle rules. The backend uses the AWS default credential chain: configure workload identity / a narrowly scoped role. For a custom endpoint configure `MYAAPTHA_S3_ENDPOINT` and validate uploads/downloads. Native GCS API is not implemented.
3. Provision Kubernetes, an ingress controller and a network-policy-capable CNI. Templates use ingress-nginx; change the ingress class and namespace for your controller. The supplied network policies restrict inbound traffic, not outbound internet access. Configure cloud firewall and egress restrictions for database, storage, AI and notification endpoints.
4. Create namespace `myaaptha`, `myaaptha-secrets` through your secret manager and the TLS certificate secret `myaaptha-tls`. Required secret keys are `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `JWT_SECRET`, `MYAAPTHA_FIELD_ENCRYPTION_KEYS` and `ADMIN_MFA_ENCRYPTION_KEY`. Generate separate 32-byte field and MFA keys; see [encryption migration instructions](security-hardening.md). Provision authenticated managed Redis (single primary endpoint, cluster mode disabled) with TLS, automatic failover and no-eviction policy; set `redis_host` in the release configuration. Use a Redis password of at least 16 characters. Use at least 16 characters for the database password and a cryptographically generated JWT secret of at least 32 bytes. Never commit secrets. Create ConfigMap `myaaptha-postgres-ca` with key `root.crt` containing the verified provider CA bundle. All three database workloads mount it at `/home/myaaptha/.postgresql/root.crt`. PostgreSQL always uses `verify-full`; Redis also requires trusted TLS. If Redis uses a private CA, provision a JVM truststore for the backend through the cloud configuration.
5. Attach the storage role to service account `myaaptha-backend`. Add provider-specific annotations through your infrastructure configuration; the generic deployment script preserves existing service-account annotations. Provide registry pull credentials if images are private.
6. Configure independent external uptime checks, cloud logs, authenticated metrics scraping, alert delivery and billing alerts. Do not expose PostgreSQL, storage administration, the AI service or unrestricted actuator endpoints publicly.

## Build and promote

- Review and commit the complete canonical source changes. Verify a fresh clone can build all three images; no local junction, worktree or dependency folder should be required.
- Protect the release branch and tags. Require successful CI checks; tagging does not bypass the workflow's CI dependency.
- Tag `vX.Y.Z`. The release workflow publishes only images that pass vulnerability scanning; retrieve image digests and SBOMs from its artifacts.
- Copy `infrastructure/release.example.json` to ignored `infrastructure/release.json`, replace all dummy values, and use `registry/image@sha256:...` digests.
- Run `python infrastructure/render_release.py infrastructure/release.json`. This writes non-secret manifests only. Placeholder values and mutable image tags are rejected.
- Restore a recent backup into staging, then run the migration and smoke checks there before production. V56 is incompatible with the previous plaintext/numeric storage. Use a maintenance window and the encryption backfill; rollback across V56 requires the verified pre-upgrade backup and its application version.
- Run `./infrastructure/deploy.ps1 -Context YOUR_STAGING_CONTEXT -ReleaseConfig infrastructure/release.json -VerifiedBackupReference YOUR_RESTORED_BACKUP_ID` first. Use a separately reviewed production config/context for production.
- The script checks secrets and the database CA, stops backend autoscaling and writers, waits for schema migration and encryption backfill, then starts the workloads and ingress. Failure leaves backend writers stopped. Pause any external writers and GitOps reconciliation during this maintenance window; prevent concurrent deployments through your release environment. Application replicas use schema validation with startup migrations disabled.
- Test public landing, registration/login/refresh/logout, unauthorized access, circles, media uploads/downloads, health, finance, messaging and enabled third-party integrations using separate test accounts. Verify a member cannot use administration endpoints.

## Single-host alternative

`infrastructure/production/docker-compose.prod.yml` uses external managed PostgreSQL and S3-compatible storage. Only ports 80 and 443 are published. Copy `.env.example` to `.env`, replace values with the same immutable image digests, and supply ignored `secrets/postgres_password`, `secrets/redis_password` and `secrets/jwt_secret` through your secret manager. Configure host workload identity for S3. Also supply `secrets/field_encryption_keys`, `secrets/admin_mfa_encryption_key`, and the provider CA as `certs/postgres-ca.crt`. Stop the old backend before upgrading; schema migration and encryption backfill must both finish before the new backend starts. This is a single-host setup; it does not provide multi-zone availability.

## Health, operations and rollback

- Kubernetes uses separate readiness and liveness probes, plus a backend startup probe. Readiness removes traffic; liveness restarts a stuck process. See https://kubernetes.io/docs/concepts/workloads/pods/probes/.
- Monitor availability, 5xx rate, p95 latency, database connections/storage, upload failures, notification backlog, certificate expiry and backup age. Establish thresholds on real staging traffic; the old local load report is not a production capacity guarantee.
- Keep the previous release config and immutable image digests. For an application-only rollback with a compatible encrypted schema, restore the prior image references with `kubectl --context CONTEXT -n myaaptha set image deployment/NAME NAME=PRIOR_DIGEST`, then check rollout status and smoke tests for all three services. Do not rerun old database migrations or automatically restore production data.
- If a migration failed, inspect the migration Job logs and database history. Do not blindly retry, repair checksums or reverse migrations; create a reviewed forward correction where necessary.
- Exercise backup restoration into a NEW database. Record restore duration, record counts and application checks. Use managed encrypted backup/PITR as the primary protection; scripts under `infrastructure/operations` are supplementary.
- Production rate-limit state is shared through Redis. Keep `MYAAPTHA_TRUST_FORWARDED_FOR=false` unless the edge strips untrusted forwarding headers; add edge limits as an additional boundary. A shared proxy IP otherwise shares the request budget.

## Launch gates

See `MYAAPTHA-DEPLOYMENT-HANDOFF.md`. Cloud provisioning, real secrets, signing, independent penetration testing, privacy review, performance acceptance and recovery drills require external execution/evidence. Templates alone do not complete those gates.

See [scaling development and validation](scaling-readiness.md) for traffic assumptions, connection budgets, test commands and capacity acceptance gates. Redis is now a required production dependency; deploy its configuration before rolling out this release.

## Repeatable local and CI checks

CI builds the web production bundle and runs browser tests against it, including nonce freshness and injected-script rejection. Backend verification includes owner isolation, malformed inputs, media payload rejection, encryption corruption/rotation and forged-token/CSRF/privilege-escalation cases. `python infrastructure/smoke_tls.py backend/spring-boot-app/target/myaaptha-service-0.1.0.jar` uses disposable loopback-only PostgreSQL/Redis containers, temporary TLS keys, and random test credentials on Linux. It runs the real production profile without disabling TLS guards. Requires Docker, OpenSSL, Java and keytool. The fixture cleans up only its own containers and volumes. Never point `smoke_backend.py` at a production database.

TLS configuration follows the [PostgreSQL JDBC certificate verification guidance](https://jdbc.postgresql.org/documentation/ssl/) and [Redis TLS configuration](https://redis.io/docs/latest/operate/oss_and_stack/management/security/encryption/). The TLS container check has not run on the current Windows host because the Docker daemon is unavailable; CI must pass before release.
