# Capacity target: 3 million accounts / 5,000 active sessions

Status: engineering target, not a production capacity certification.

The account count describes stored data. Active sessions describe workload. They
must be tested independently and together on the intended deployment. Local tests
use disposable PostgreSQL/Redis containers and two API replicas; they cannot
certify hosting capacity.

## Changes

- Circle directories batch user/profile reads (500 IDs per batch), keep each
  owner's contact names separate, and batch member/admin collection loading.
  Owner/member visibility uses indexed UNION branches without duplicate circles.
- Mobile checks incoming calls every five seconds and summaries every fifteen
  seconds. Open-chat refresh remains independent. Nominal background requests
  fall from 25 to 7 per fifteen seconds; this is arithmetic, not a benchmark.
- Web heartbeats run every fifteen seconds; presence is read only for open
  conversations. Timeline refresh uses visibility-aware polling every two minutes.
- The disposable database harness accepts three million synthetic accounts.
- `testing/k6/concurrent-sessions.js` requires one unique fixture account per VU,
  refreshes sessions throughout a soak, and fails on slow polling cycles as well
  as HTTP errors and latency. It exercises reads, presence writes and refresh;
  message creation, uploads, AI inference and call media need separate workloads.

## Reproducible local checks

With Java 21, Docker, OpenSSL and keytool on PATH, after packaging the API:

```powershell
python infrastructure/validate_scaling.py backend/spring-boot-app/target/myaaptha-service-0.1.0.jar --records 3000000 --load --rate 50 --duration 2m --warmup 30s
python infrastructure/validate_scaling.py backend/spring-boot-app/target/myaaptha-service-0.1.0.jar --records 3000000 --load --workload sessions --sessions 19 --ramp 30s --duration 2m
```

The local harness intentionally limits active fixtures to 100. Each receives
2,000 historical messages; all share one test circle. It deletes token fixtures
and disposable containers on exit and does not modify preview or external data.
Local rows use short uniform messages and disabled background accounts, not full
production profiles, encrypted-content sizes or varied contact graphs.
Reports appear under `.tools/scaling`; preserve reports before a subsequent run.
A failed acceptance gate is a failure even when average latency looks good.

## Staging acceptance

Use an isolated production-shaped staging environment with at least 3 million
accounts, representative profile/contact/relationship distributions, realistic
circle sizes and retention-sized message tables. Provision at least 5,000 distinct
synthetic accounts with `id`, `token`, `refreshToken`, `otherId`, `circleId` in a
private JSON file. Peers and circles must be accessible to each account. Do not
reuse tokens across load generators or commit the file.

Run the session script with `VUS=5000`, `RAMP=10m`, `DURATION=30m`, then repeat
with `DURATION=2h`. Set `ORIGINS` to staging and `ACCOUNTS_FILE` to the private
fixture. Defaults target local disposable replicas. Production auth limits apply:
provision distributed generator egress or an explicitly approved staging-only
allowlist; do not disable production protections to obtain a pass. Include real
shared-IP/mobile-carrier login and refresh bursts in the deployment review, since
current authentication budgets are per IP.

The baseline model offers approximately 2,820 requests/second at 5,000 sessions:
5-second incoming-call checks, four summary requests every fifteen seconds,
20% of sessions reading two histories every five seconds, and directory reads
once a minute. This is a model, not exact browser replay: open web chats poll more
frequently. Add measured web/mobile mix, message sends, fan-out, searches, uploads,
AI concurrency and call signalling/media before launch acceptance.

Gates: HTTP failures below 1%, p95 below 1,500ms, checks above 99%, and fewer than
1% cycles exceeding five seconds. Also run fixed-arrival tests with zero dropped
iterations, record achieved request rate and completed active VUs, and inspect
per-endpoint latency. Passing aggregate thresholds alone is insufficient.

Monitor database CPU/IO, query plans and locks; connection-pool waits; Redis
latency/evictions; API CPU/heap/GC; queues; storage/CDN traffic; generator CPU and
network. Exercise rolling deploy, one-replica loss, Redis/database failover and
backup restoration under load. Record host sizes, region, dataset, commit and
configuration with results.

## Hosting preparation

Use multiple stateless API/web replicas behind TLS/load balancing, managed HA
PostgreSQL and Redis, private object storage/CDN, and separately bounded AI jobs.
The release renderer already checks database connection budgets, including one
rolling-update surge replica: `(maximum replicas + 1) * pool size + reserve`.
Its default 10 replicas, 20 connections each and 40 reserved requires 260 database
connections; these defaults do not prove throughput or prescribe server size.
Select resource sizes from measured saturation and leave headroom for failure and
traffic spikes. Confirm monitoring, alerting, secrets, provider credentials,
restore procedures and operating costs before public launch.

## Verification on 27-28 September 2026

- Backend package: 126 tests, zero failures/errors, one skipped. The earlier
  prolonged run had one HTTP 401 authentication failure; the complete
  rerun passed without changing authentication or weakening test assertions.
- Web production build passed; all 11 unit tests passed.
- Flutter analysis reported no issues; all 24 tests passed. Android debug APK
  built and archive integrity verified (existing Kotlin/Android SDK warnings remain).
- Desktop and mobile-web messaging integration tests both passed. Web, API and
  AI readiness endpoints returned HTTP 200 after restoring the local preview.
- First three-million-account run: pagination, user isolation and shared rate
  limits passed across two replicas with 3,040,000 direct messages. Session load
  FAILED: 19 peak VUs, 1,777 requests, 9 timeouts (0.506%), p95 75.7ms, and
  9/631 cycles exceeding five seconds (1.426%, above the 1% gate). The low
  response-time percentile does not cancel the timeout/cycle failure. API logs
  contain multi-hour clock gaps and closed-connection warnings preceding load.
  Cause of each timeout is not established. Raw evidence is preserved under
  `.tools/capacity-first-run`.
- Warmed rerun: local acceptance thresholds PASSED, with the same dataset and
  19 peak simultaneous accounts. Thirty-second warm-up excluded from acceptance;
  30-second ramp, two-minute hold and one-minute ramp-down. There were 1,812
  requests (8.56/second including ramps), 636 completed cycles and zero interrupted
  iterations. HTTP p95 was 46.7ms; 3 requests timed out (0.166%) and 3/636 cycles
  exceeded five seconds (0.472%). All three timeouts were incoming-call reads
  across the two replicas; their cause remains unresolved. Because timeouts
  recurred in the clean run, they cannot all be attributed to host suspension. This is not a zero-error
  result or a 5,000-session certification. Evidence: `.tools/capacity-warmed-run`.
  Both API replicas used a 384MiB Java heap and shared disposable local Docker
  PostgreSQL 17 / Redis 7 with TLS. No media, AI inference or message-send capacity
  claim follows from this measurement.
- A subsequent local run reached 5,000 active users but failed acceptance, with
  both server overload and load-generator saturation. See the newer
  [5,000-user verification](capacity-5000-verification.md) for measurements and
  follow-up changes. No production-hosting capacity certification is claimed.
