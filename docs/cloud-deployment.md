# Cloud deployment runbook

MyAaptha is ready to run from the tagged container images produced by
`.github/workflows/release.yml`. The supported production baseline is the
Kubernetes configuration in `infrastructure/kubernetes`; the single-host
Compose configuration is intended for a small controlled installation or a
staging environment.

## Production architecture

Use three independently scalable workloads: Next.js frontend, Spring Boot API,
and the FastAPI AI service. Put only the frontend and `/api` gateway routes on
the public load balancer. Keep PostgreSQL, the AI service, and object storage
private. Use a managed PostgreSQL 17-compatible service, private S3-compatible
object storage, a cloud secret manager, centralized logs/metrics, TLS, WAF,
automated backups, and at least two application replicas across zones.

The backend runs Flyway migrations when it starts. During a release, run one
backend migration task first, confirm it succeeds, and only then roll the API
deployment. Database migrations must remain backward compatible with the
previous application version so rolling updates and rollback are safe.

## AWS reference deployment

- EKS (using the supplied manifests) or ECS Fargate for the three workloads.
- RDS for PostgreSQL with Multi-AZ, encryption, deletion protection, PITR, and
  a private subnet.
- A private S3 bucket with block-public-access, versioning, lifecycle policy,
  KMS encryption, and an IRSA/task-role granting only required object actions.
- ALB, ACM, Route 53, and AWS WAF for ingress, certificates, DNS, and edge
  protection; CloudWatch and Managed Prometheus for logs, alerts, and metrics.
- Secrets Manager plus External Secrets Operator for `POSTGRES_PASSWORD`,
  `JWT_SECRET`, and notification-provider credentials.

Set `MYAAPTHA_S3_REGION` and `MYAAPTHA_S3_BUCKET`; leave
`MYAAPTHA_S3_ENDPOINT` empty for AWS S3.

## GCP reference deployment

- GKE Autopilot (using the supplied manifests) for the three workloads.
- Cloud SQL for PostgreSQL with HA, private IP, automated backups, and PITR.
- A private object store exposed through an S3-compatible endpoint, with
  workload identity and a dedicated least-privilege service account. The
  current application storage adapter speaks the S3 API; a native GCS adapter
  is required before using the JSON GCS API directly.
- External Application Load Balancer, managed certificates, Cloud DNS, and
  Cloud Armor; Cloud Logging and Managed Service for Prometheus for operations.
- Secret Manager plus External Secrets Operator for application secrets.

Set `MYAAPTHA_S3_ENDPOINT` when the selected GCP object-storage gateway needs
one. Validate multipart upload, signed access, lifecycle, and restore behavior
in staging before production promotion.

## Required release configuration

Replace every `OWNER`, `VERSION`, example hostname, bucket, and database host
in `infrastructure/kubernetes`. Create `myaaptha-secrets` from the cloud secret
manager—never from a committed file. `JWT_SECRET` must be a cryptographically
random value of at least 32 bytes. Set the repository variable
`PRODUCTION_API_URL` for Android/iOS release builds.

Required runtime values are `POSTGRES_HOST`, `POSTGRES_DB`, `POSTGRES_USER`,
`POSTGRES_PASSWORD`, `JWT_SECRET`, `MYAAPTHA_CORS_ALLOWED_ORIGINS`,
`MYAAPTHA_STORAGE_PROVIDER=s3`, `MYAAPTHA_S3_BUCKET`, and
`MYAAPTHA_S3_REGION`. Set notification and OAuth credentials only through the
secret manager. The production profile does not create demo users.

## Promotion checklist

1. Protect `main`; require the CI workflow and reviewed pull requests.
2. Tag an audited commit (`vX.Y.Z`) and wait for images and mobile artifacts.
3. Scan the images, generate/store an SBOM, and promote immutable image digests.
4. Restore the latest backup into staging and run migration plus API/UI smoke
   tests against the restored data.
5. Apply namespace, external secrets, config, workloads, ingress, and network
   policies. Run the one-off migration task before rolling the backend.
6. Verify `/actuator/health`, `/api/v1/ready`, login/refresh/logout, diary
   audience rules, uploads/downloads, messages, circles, and mobile deep links.
7. Enable alerts for availability, 5xx rate, p95 latency, database saturation,
   storage failures, queue/backlog growth, and certificate/backup expiry.
8. Roll back to the prior image digest if health or smoke checks fail. Restore
   data only for a confirmed data-loss event; application rollback must not
   automatically reverse migrations.

Before launch, complete a threat model, penetration test, data-retention and
privacy review, disaster-recovery exercise, load test, and app-store signing
and privacy declarations. These are operational launch gates, not code-only
checks.
