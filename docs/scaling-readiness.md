# MyAaptha scaling and security readiness

For the current 3-million-account / 5,000-session engineering target, see
[Capacity target and validation](capacity-target.md).
The latest measured 5,000-user result and remaining gates are recorded in
[5,000-user verification](capacity-5000-verification.md).

For earlier source changes and the 300,000-account validation, see
[23–24 September validation](validation-2026-09-23.md). The assessment below is
historical; several listed application gaps have since been addressed.

Review date: 6 September 2026. Release source: backend/spring-boot-app, frontend/nextjs-app, ai/agent-service and mobile/flutter-app. The smaller legacy scaffold is not the release application.

## Decision

Do not treat this release as certified for a few million users' traffic or as security-approved for a public launch. Substantial scaling and security safeguards are implemented and tested. A controlled staging deployment is the next step after provisioning its real dependencies. Production approval remains conditional on the items below.

One million registered accounts is a database-size assumption. It does not specify simultaneous sessions, requests per second, media bandwidth, login bursts, AI workload or availability. A few million simultaneous users would require a very different architecture and budget from a few million registered users.

## Implemented in this development pass

| Area | Change and purpose |
| --- | --- |
| Shared abuse limits | Atomic Redis counters across replicas. Authenticated API budgets use the verified user identity; authentication budgets use the client IP. Redis failure returns 503 instead of silently disabling protection. |
| Proxy safety | Raw forwarded-header trust is rejected. Native Tomcat forwarding uses an explicitly configured trusted proxy expression. Restrict backend network access to those proxies. |
| Resource exhaustion | Nonblocking limits of 100 requests and 4 multipart uploads per API instance; 503 and Retry-After on overload. JSON bodies are limited to 1 MiB, including streams without Content-Length. Existing uploads remain limited to 25 MiB. |
| Database protection | Hikari pool 20, 2-second acquisition timeout, database statement and lock timeouts, batched updates, graceful shutdown and bounded server connection queues. Open Session in View disabled and tests run with that production behavior. |
| Message histories | Default 50, maximum 100 records, beforeId cursor; web and mobile Load earlier controls. Search returns at most 100 matches. Only returned incoming messages are marked read. |
| Unread counts | Member-scoped SQL circle counts replace whole-platform scans. Inbox reduction and unread aggregation run in SQL instead of loading every message into Java. |
| Concurrent reads | Batched PostgreSQL ON CONFLICT read receipts avoid duplicate-insert races across replicas. |
| Presence | Redis-backed expiring presence and typing; circle typing uses batched reads. Redis cluster mode disabled is required for the current multi-key reads. |
| Background delivery | Durable database leases with SKIP LOCKED, expiry recovery and claim-token fencing. Provider calls occur outside database transactions; webhook requests have finite timeouts and stable Idempotency-Key headers. |
| Scheduled cleanup | Database locks prevent simultaneous retention batches on multiple replicas. |
| Media | Private S3 responses stream from storage rather than buffering each download in API heap. |
| Browser polling | Dashboard polling pauses in hidden tabs, waits for completion, and uses jitter; selected errors trigger backoff. Inbox polling interval increased to 15 seconds. |
| Refresh security | Pessimistic locking prevents concurrent consumption of one refresh token. Suspended accounts cannot refresh. Existing hashed refresh-token storage and rotation retained. |
| Deployment | Redis and trusted-proxy configuration wired into Compose, Kubernetes and release rendering. Frontend and AI autoscaling added; backend replica/pool settings validated against the database connection budget including a rollout surge. |
| Edge defense | AWS regional ALB WAF template includes managed threat rules, authentication and general IP rate rules, and redacted logs. This is a template, not an active deployed firewall. |

## Verification

- Backend: 83 tests passed, zero failures/errors/skips in the final run, including a real isolated Redis instance.
- Frontend: production build passed; three message-page regression tests passed.
- Release renderer: four tests passed, including the database connection-budget boundary.
- Current dependency scans: zero reported high/critical findings in the backend and AI manifest scans; npm production audit reported zero findings at all severities.
- Source secret scan: zero detections in a 496-file source export, excluding caches, local secrets, build output and the preserved worktree. This was not a full Git-history scan. POM files were scanned as text to avoid unrelated Maven dependency resolution during secret scanning.
- Flutter tooling was unavailable locally. Mobile pagination source is updated; Flutter analysis/tests and real-device checks remain required in CI.
- Existing authorization tests cover administrator boundaries, user/circle isolation, invitation-claim denial, privacy, malicious files and input limits. These tests are not an independent penetration test.
- Container OS/image scanning remains a required release-CI gate; dependency scan results must not be represented as a clean scan of every final container layer.

### Measured local large-data result

The completed isolated run used two production-profile API JVMs (384 MiB maximum heap each), real PostgreSQL 17 and Redis 7, one million synthetic background users plus 20 test accounts, 1,040,000 direct messages and 100,500 circle posts. Cross-replica rate limits, user-budget isolation, cursor pagination and concurrent circle reads passed.

A 30-second k6 test at 20 requests/second completed 601 requests with zero HTTP failures, zero dropped iterations and 100% checks passing. HTTP p95 was 369.8 ms; maximum was 1.24 seconds. The mix covered authenticated message pages, inboxes and circle unread counts using 19 synthetic sessions. The maximum VUs actually observed was 8.

This is a local correctness and small-load measurement over a large dataset. It does not measure one million simultaneous users, cloud autoscaling, sustained login/upload/AI traffic, adversarial traffic, geographic latency or failover. Do not extrapolate it into a million-user traffic guarantee. A prior attempt was invalidated by a long host clock/suspend interruption and expired test sessions; only the completed rerun is reported here. Temporary API processes, labelled containers and account-token files are removed by the runner.


## Required before public production approval

| Priority | Required work or evidence | Owner/input |
| --- | --- | --- |
| High | Move web refresh/session credentials out of localStorage into a reviewed HttpOnly, Secure, SameSite cookie/server session design, with corresponding CSRF and cross-origin tests. Current CSP reduces some XSS risk but does not make JavaScript-readable tokens safe against XSS. | Application development and authentication-flow review |
| High | Add verified phone/email ownership before relying on these identifiers for invitations or identity; complete safe recovery and administrator MFA. Invited-account claiming is currently blocked; ordinary registration still accepts a supplied phone number. | Identity provider, SMS/email service, approved enrollment and recovery rules |
| High | Add a real malware-scanning/quarantine pipeline with updated signatures for uploaded files. BasicMediaScanner validates extensions, signatures, archive expansion and selected content; it is not a comprehensive antivirus engine. | Private storage, scanning service, quarantine and retention decisions |
| High | Deploy and test edge WAF, bot/rate controls, DDoS protection, TLS and origin restrictions. Confirm public traffic cannot bypass the edge via origin addresses. Tune managed rules against legitimate uploads and mobile traffic. | Cloud account, domain, existing ALB or chosen edge architecture |
| High | Independent authenticated penetration test, remediation and retest covering account takeover, object authorization, uploads, SSRF, injection, privilege escalation and AI tool actions. | Authorized security test against isolated staging |
| High | Sustained representative load and soak test with agreed latency/error targets; validate database/Redis failover, autoscaling, rollout and recovery under load. | Traffic model, staging budget and provisioned cloud resources |
| High | Configure alerts, audit-log retention, on-call response and backup/restore drills with agreed recovery objectives. | Operations owners and availability/recovery targets |
| Medium | Verify access-token revocation policy. Existing access JWTs can remain valid until expiry after logout/account changes; immediate revocation needs additional enforcement. | Session policy and security implementation |
| Medium | Continue optimizing workload-specific paths: social feeds/comments, large relationship graphs and circle fanout; use queued AI/media processing if sustained volume or response times demand it. Current limits are protective bounds, not capacity guarantees. | Measured workload and product group-size limits |

## Deployment inputs to supply

1. Cloud account/region, DNS domain, certificate ownership, private network and workload identities.
2. Managed PostgreSQL endpoint, database/user, password from a secret manager, TLS CA, instance capacity and maximum connection allowance.
3. Managed Redis primary endpoint, strong password, TLS, automatic failover, monitoring and no-eviction policy. Use cluster mode disabled for this release. Keep durable business data in PostgreSQL.
4. Actual trusted ingress/frontend proxy addresses as TRUSTED_PROXY_REGEX; never use a match-all expression or trust client-supplied X-Forwarded-For directly.
5. Private S3 bucket, region, access identity, encryption/retention policy and malware-scanning design.
6. Immutable image digests and cloud-secret keys JWT_SECRET, POSTGRES_PASSWORD and REDIS_PASSWORD. Do not put secrets in this document or source control.
7. Peak concurrent active users, target requests/second, expected uploads/second and size, AI jobs/minute, notification volume, geographic split and growth assumptions.
8. Auth/SMS/email provider choices, MFA/recovery rules, privacy/consent requirements and security/operations owners.

Default database budget: (10 API replicas + 1 rolling-update surge) x 20 connections + 40 reserved = 260. This is a connection ceiling calculation, not a recommendation that an arbitrary database tier can sustain the workload. CPU-based autoscaling alone does not diagnose a slow database or external AI provider.

## Reproduce and promote

- Build backend with `mvn verify` in backend/spring-boot-app. Set REDIS_TEST_HOST, REDIS_TEST_PORT and REDIS_TEST_PASSWORD for the real Redis regression test; CI provisions a disposable Redis service.
- Run `npm run build` and `npm run test:unit` in frontend/nextjs-app; run Flutter analyze/test in CI.
- Run `python -m unittest discover -s infrastructure -p 'test_*.py'`.
- Isolated data test: `python infrastructure/validate_scaling.py backend/spring-boot-app/target/myaaptha-service-0.1.0.jar --records 1000000 --load`. Requires Docker Desktop and Java 21; fixed loopback ports must be free. The script creates temporary labelled containers, uses generated secrets, and removes containers and test tokens. On Linux, run k6 on the host with explicit reachable origins because host networking differs from Docker Desktop.
- For cloud load tests, use testing/k6/scaling.js with synthetic account tokens and explicit ORIGINS/RATE/DURATION. Initial local thresholds are p95 under 1.5 seconds, less than 1% request failures and zero dropped iterations; agree on stricter product targets for cloud acceptance.
- Render real release configuration, provision dependencies/secrets, run migrations V52/V53 through the one-off migration task, deploy to staging and collect evidence. Index creation is transactional and can block writes on existing busy tables; review maintenance timing before promotion.
- infrastructure/security/aws-waf.yaml is a regional ALB CloudFormation template. It is not CloudFront configuration and has not been deployed or validated by AWS in this session. Validate it in the selected account and region. The body-size rule override allows legitimate large uploads; application upload/body limits remain mandatory. Review path/query logging for personal data even with Authorization/Cookie redaction.

## Reference guidance

- OWASP: https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html
- AWS rate-based WAF rules: https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-type-rate-based.html
- PostgreSQL locking: https://www.postgresql.org/docs/current/sql-select.html
- Redis atomic counters: https://redis.io/docs/latest/commands/incr/
