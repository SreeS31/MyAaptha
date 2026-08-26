# MyAaptha production operations

## Service objectives

- API availability target: 99.9% monthly.
- Alert when 5xx responses exceed 2% for five minutes, p95 latency exceeds 1.5 seconds for ten minutes, database connections exceed 80%, notification failures exceed 5%, or storage quota failures spike.
- Scrape `/actuator/prometheus`; retain metrics for at least 30 days and centralize structured container logs.

## Backup and recovery

- Run encrypted managed PostgreSQL snapshots daily and point-in-time recovery continuously.
- Run `infrastructure/operations/backup-postgres.ps1` for portable weekly dumps; copy them to a versioned, immutable cross-region bucket.
- Test `restore-postgres.ps1` monthly in an isolated account. Record recovery time and row-count/integrity checks.
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
