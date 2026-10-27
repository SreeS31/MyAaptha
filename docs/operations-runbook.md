# MyAaptha production operations

## Service objectives

- API availability target: 99.9% monthly.
- Alert when 5xx responses exceed 2% for five minutes, p95 latency exceeds 1.5 seconds for ten minutes, database connections exceed 80%, notification failures exceed 5%, or storage quota failures spike.
- Scrape `/actuator/prometheus` using an administrator session or the optional protected `MYAAPTHA_METRICS_SCRAPE_TOKEN`; ordinary members and anonymous callers are denied. Retain metrics for at least 30 days and centralize structured container logs. See [operational access and readiness](launch-board/OPERATIONAL-METRICS-2026-10-20.md). Configure private TLS collector access, network policy and actual alert recipients before release.

## Backup and recovery

- Run encrypted managed PostgreSQL snapshots daily and point-in-time recovery continuously.
- Run `infrastructure/operations/backup-postgres.ps1` for portable weekly dumps; copy them to a versioned, immutable cross-region bucket.
- Test `restore-postgres.ps1` monthly in an isolated account. Record recovery time and row-count/integrity checks.
- Portable dumps require an explicit PostgreSQL client connection URL and include a mandatory SHA-256 sidecar for restore. Restore rejects inaccessible/nonempty targets. See [local recovery guards and their limits](launch-board/RECOVERY-GUARDS-2026-10-18.md); keep the target isolated from all writers.
- Enable S3 versioning, lifecycle policies, and cross-region replication for media.
- Targets: RPO 15 minutes, RTO 4 hours.

## Incident response

1. Acknowledge the alert and assign an incident commander.
2. Preserve logs and audit events; rotate compromised credentials through the secret manager.
3. Disable affected features or roll back to the last immutable image tag.
4. Restore data only into an isolated environment first; validate migrations and checksums.
5. Notify affected users as required, write a blameless postmortem, and track corrective actions.

## Privacy and moderation

- Contact mobile numbers and email addresses remain private relationship data.
- Review abuse reports through the admin moderation API; retain decisions and audit events.
- Fulfil deletion/export requests using authenticated workflows and remove corresponding media objects.
- Review IAM, bucket policy, CORS, notification providers, and data retention quarterly.

## Rollback preparation

Use the [offline rollback planner](launch-board/ROLLBACK-PLANNER-2026-10-20.md) to compare reviewed non-secret release configurations before a rehearsal. A generated plan does not establish schema compatibility, live alert delivery, deployment approval or a completed rollback.
