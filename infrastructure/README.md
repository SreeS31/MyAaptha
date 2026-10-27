# Production deployment

- `production/docker-compose.prod.yml` is a single-host production baseline with automatic TLS through Caddy, non-root application images, Docker secrets, health checks, external managed PostgreSQL/Redis, and restart policies.
- `kubernetes/` is the managed-cloud baseline with two replicas, health probes, resource boundaries, horizontal autoscaling, non-root/read-only containers, and secret-manager integration points.
- Tagged releases build and publish immutable backend/frontend/AI images through `.github/workflows/release.yml`.
- `../docs/cloud-deployment.md` contains the AWS/GCP architecture, release configuration, promotion, smoke-test, monitoring, and rollback checklist.

Use a managed PostgreSQL database, managed Redis, private S3 bucket, workload identity, external-secrets operator, ingress/certificate manager, monitoring, and backup service for cloud production. Replace `OWNER`, `VERSION`, domains, and example endpoints during promotion. Never commit rendered secrets.

## Read-only release prerequisite check

Run `python infrastructure/preflight_release.py infrastructure/release.json` before preparing deployment. It checks local release configuration and protected secret/CA formats without contacting infrastructure or exposing values. [Scope, options and acceptance boundaries](../docs/launch-board/RELEASE-PREFLIGHT-2026-10-20.md).

## Disposable object-storage recovery drill

Run `python infrastructure/smoke_s3_recovery.py --tls` to exercise the actual S3 adapter against a cached local TLS/SSE fixture with synthetic data. It never accepts an external endpoint or existing bucket. [Verified scope and remaining provider gates](../docs/launch-board/S3-RECOVERY-2026-10-21.md).
