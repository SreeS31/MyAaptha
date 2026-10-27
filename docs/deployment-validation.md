> Updated scaling/security assessment: see [scaling-readiness.md](scaling-readiness.md). Earlier deployment checks below are historical evidence, not public-production or million-user capacity approval.

# Deployment validation - 6 September 2026

## Confirmed locally

- Full canonical backend: 71 tests, zero failures/errors, after Spring Boot 3.5.16 and dependency security updates.
- Frontend production build: passed. Existing image-optimization lint warnings remain.
- Public browser/accessibility checks: all four desktop/mobile cases passed. Windows development-server teardown remained running after the tests; container production build also passed independently.
- AI service: six pytest tests passed.
- Release renderer: three tests passed, including rejection of placeholders and mutable image tags.
- Production Compose: configuration parsed successfully using dummy planning values; no deployment with those values was attempted.
- Actual PostgreSQL 17: 50 common migrations applied successfully through V51; repeat migration invocation was valid.
- Packaged production API: schema validation, readiness/liveness, registration/login/refresh, member denial on administration endpoints, and cross-user circle isolation passed against an isolated database.
- Local backup/restore: custom-format PostgreSQL dump restored into a NEW disposable database, retaining two synthetic users and 50 successful migration records.
- Frontend production dependency npm audit: zero known vulnerabilities at check time.
- Backend dependency Trivy scan: initial old dependencies had high/critical findings; after upgrades the rescan reported zero high/critical findings. The scan used the populated Maven cache after a Maven Central HTTP 429 blocked the first attempt. This result covers dependency scanning, not a penetration test or all container OS packages.
- Final backend image: started successfully as UID/GID 10001 with a read-only root filesystem; database-aware readiness returned UP.
- Clean production Docker builds: frontend, AI service and backend passed. Backend dependency prefetch was removed after unrelated offline-plugin resolution failed; normal packaging with a temporary Maven mirror succeeded.

## Corrections driven by testing

Production S3 startup initially failed because the old HTTP client dependency lacked TlsSocketStrategy. The updated dependency set passed the packaged production-profile startup test. The existing global dashboard test was corrected to require an administrator. New checks cover production placeholders, cross-user administration access, and unverified invitation claims.

Two chosen Windows test ports failed to bind; the successful check used a verified available loopback port. The smoke script now checks the port before starting the application.

## Not yet verified / external gates

- Final runtime images' complete OS/dependency/secret security assessment; release CI blocks image publication on high/critical findings.
- Cloud IAM, private networking, database TLS/CA, DNS/certificates and live secret-manager integration.
- Real S3 upload/download and recovery with the chosen workload identity.
- External AI, notification, OAuth, identity-verification and mobile signing integrations.
- Current Flutter verification on a machine/CI runner with the Flutter SDK.
- Independent penetration/privacy review and representative production-capacity load testing.
- Production backup scheduling/PITR, alert delivery and multi-zone failure/rollback exercises.
- Review/commit the canonical source and execute remote CI from a fresh checkout.

No cloud resources were provisioned, images published, third-party notifications sent, or real user data used for these checks. Temporary test credentials are excluded from Git. The smaller MySQL scaffold remains reference-only and is not covered by production readiness claims.
