# Operational endpoint authorization and readiness

Date: 20 October 2026. Related launch gates: M15.7, M18.4 and M16.6.

The JWT filter previously skipped non-API paths, including Actuator. Protected
operational endpoints could not use application bearer sessions; the authorization
fallback also expressed general authentication rather than an administrative role.
Protected Actuator routes now authenticate normally and have explicit access rules.

| Request | Required access |
|---|---|
| `/actuator/health`, `/actuator/health/liveness`, `/actuator/health/readiness` | Public probes; production hides component details. |
| `GET /actuator/prometheus` | Administrator session or configured read-only scrape credential. |
| Other Actuator routes, including info/discovery | Administrator session. |
| Application/account APIs | Existing account authorization; scrape credentials cannot authenticate here. |

The optional secret-manager value `MYAAPTHA_METRICS_SCRAPE_TOKEN` is disabled when
absent. Configured values require 32–512 UTF-8 bytes; use a cryptographically random
URL-safe token. The application retains its SHA-256 digest and compares fixed-size
digests in constant time. It is accepted only on exact `GET /actuator/prometheus`
requests and creates no user account or administrator session.

The production profile exposes this endpoint. Other profiles may leave it unexposed.
Send the token in a bearer header; keep it out of URLs, logs and configuration maps.
Configure an approved private/TLS scrape path and narrowly scoped collector network
access. This change does not install a collector or open Kubernetes ingress; existing
default-deny policies require separate collector access configuration.

The token has no automatic expiry. Coordinate collector/application rollout for
rotation and revocation. Live TLS/network setup, monitoring retention, alert recipients
and operating procedures still require acceptance on the selected platform.

## Verification

Isolated application tests cover public probes with hidden details, member denial,
a synthetic H2 administrator, scrape scope and invalid credentials. No real account
is promoted. Authentication/recovery/scaling regressions remain part of verification.

The packaged production smoke uses disposable TLS PostgreSQL/Redis and synthetic
credentials. Its dependency-outage checks require readiness 503/DOWN, available
liveness and authenticated metrics, and readiness recovery after restart. Only
containers created by that harness are stopped. Existing capacity/scaling callers
retain the two-value TLS fixture interface.

Local results are recorded in the [current report](DEVELOPMENT-2026-10-20.md).
These checks do not establish live monitoring, alert delivery, production rollback,
backup/PITR recovery, representative capacity or independent security approval.
