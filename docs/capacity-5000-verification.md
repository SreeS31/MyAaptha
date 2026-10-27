# 5,000-user verification (28 September 2026)

Target: 5,000 distinct simultaneous active accounts against 3 million background
accounts. This is an active-session HTTP workload, not 5,000 requests issued at
exactly the same instant and not millions of simultaneous users.

## Latest requested rerun: failed

Evidence: `.tools/capacity-20260928-195313`, completed 28 September at 21:47 IST.
The UI/build/browser processes were stopped during measurement. The existing user
database was untouched. Same two-replica configuration and acceptance gates as
below; this rerun added a 30-second API-read warm-up (3,060 successful requests)
and a temporary Windows automatic-sleep prevention request, restored on exit.
Warm-up is excluded from all measurements below.

| Measurement | Result | Acceptance |
| --- | ---: | ---: |
| Peak active users | 5,000 | 5,000 |
| Distinct users issuing requests during hold | 5,000 | 5,000 |
| Users with successful requests during hold | 4,403 | 5,000 |
| Total requests / failures | 137,038 / 65,733 | Errors below 1% |
| Overall error rate | 47.97% | Below 1% |
| Hold error rate | 65.19% | Below 1% |
| Client-observed p95 | 18,015ms | Below 1,500ms |
| Hold p95 | 17,891ms | Below 1,500ms |
| Hold throughput, including failed requests | 396.93 requests/s | At least 2,500 requests/s |
| Cycles over five seconds | 93.86% | Below 1% |
| Generator event-loop lag p95 / maximum | 8,406ms / 15,343ms | p95 below 100ms |

The configured three-minute hold included requests from all 5,000 users, unlike
the interrupted previous retest. However, the generator was saturated too: these
latencies include scheduling delay and cannot isolate server response time.
Host CPU reached 100%, available physical RAM fell to 270MiB, and the runtime
reported timeouts, disconnections and server errors. Do not use this result as
an estimate of capacity on separate production servers or as a launch pass.
Reaching the target user count did not satisfy the performance requirements.

## Application changes

- Incoming-call expiration now filters in the indexed database query. Historical
  ringing calls older than 90 seconds are not materialized and discarded in Java.
- PostgreSQL circle receipts insert missing rows in one bounded statement, instead
  of attempting an insert for every message on every poll. Existing receipt times
  remain unchanged. ON CONFLICT protects concurrent readers.
- The production keep-alive connection ceiling is configurable via MAX_CONNECTIONS
  (default 8,192). The existing 100 in-flight requests and 20 database connections
  per replica remain bounded; idle sockets do not justify unbounded database work.
- HTTP_KEEP_ALIVE_TIMEOUT now defaults to 30 seconds, separately from the five-second
  request connection timeout. The fixture checks that the same TCP connection still
  serves a request after six idle seconds. Previously Tomcat inherited the five-second
  connection timeout for keep-alive, matching the polling interval. See the
  [Tomcat connector documentation](https://tomcat.apache.org/tomcat-10.1-doc/config/http.html).
  This configuration correction alone is not evidence that the load failures are resolved.

## Reproduction

```powershell
python -m pip install --target .tools/capacity-python -r testing/capacity-requirements.txt
python infrastructure/capacity_sessions.py backend/spring-boot-app/target/myaaptha-service-0.1.0.jar --generator async --sessions 5000 --records 3000000 --ramp 180 --hold 180 --warmup 30
```

Requires Java 21, Docker, OpenSSL and keytool on PATH. The harness creates only
isolated disposable PostgreSQL/Redis containers and does not accept an external
database. Reports get a timestamped `.tools/capacity-*` directory. Temporary tokens
are deleted and services removed on exit. Native k6 is also supported with
`--generator k6 --k6 <path>`; its per-user JavaScript runtimes need more RAM.

## Workload and acceptance

One task and distinct account per active user; groups contain up to 50 members.
Each active account has 100 historical incoming messages and 20 expired call
records. Background data contains 3 million users and 3 million messages. Sessions
are seeded with disposable signing keys and database fingerprints, then exercise
real revocation checks and refresh rotation. Password-login throughput is not
included. Synthetic users have distinct benchmark IPs passed through the explicitly
trusted loopback proxy boundary; production 10/minute auth and 300/minute per-user
API limits remain enabled. No production allowlist or authentication bypass exists.

Traffic includes incoming-call polling, presence heartbeats, inbox/notification/
circle counts, 20% active conversation readers, circle directories and a message
send per minute for 10% of users. Attachments, AI inference, large fan-out and call
media need additional workloads. Uniform synthetic records are not a full estimate
of production data sizes or contact graph distributions.

Gates require all users to start and succeed during the full-load period, peak
active users equal the target, errors below 1%, p95 below 1,500ms, fewer than 1%
cycles over five seconds, and at least 0.5 requests/second/user during the hold.
Generator event-loop lag p95 must remain below 100ms. Resource samples include host
CPU/RAM and API/generator process CPU and memory. A resource safety stop is not a
capacity pass.

Local configuration: Windows host with 16GB RAM / 8 logical CPUs, two API replicas
with 256MiB heaps, PostgreSQL container capped at 768MiB, real TLS Redis/PostgreSQL,
and loopback HTTP for API traffic. Public TLS/load-balancer, HA/failover and a long
soak are separate deployment gates.

## Evidence so far

- Backend: 127 tests, zero failures/errors, one skipped; package succeeded.
- Real PostgreSQL fixture checks include concurrent same-user receipt writes and
  repeated polling with unchanged receipt timestamps.
- An initial native-k6 20-user run was stopped by the low-memory guard before a
  valid measurement. It is not reported as an application capacity failure/pass.
- The lightweight 20-user check passed: 492 requests, zero errors, zero cycle
  overruns, all 20 users successful during hold. Evidence:
  `.tools/capacity-20260928-084135`.
- First full 5,000-user measurement **FAILED**. Evidence:
  `.tools/capacity-20260928-084420`. All 5,000 distinct users started and issued
  requests in the hold, but only 4,252 succeeded during it. There were 127,259
  requests, 74,342 failures (58.42%), overall p95 17,109ms and hold p95 17,641ms.
  Hold throughput was 374.8 requests/second, below the required 2,500; 96.12% of
  cycles exceeded five seconds. The generator's own event-loop lag p95 was
  6,485ms, far above its 100ms gate. Client timeouts/disconnections, server busy
  responses and database-pool acquisition timeouts were observed. The shared
  desktop saturated, so this is neither a production capacity certification nor
  a reliable estimate of the application's maximum throughput on separate servers.
- The keep-alive retest also **did not pass**. Evidence:
  `.tools/capacity-20260928-155418`. The six-second TCP reuse and all database
  fixture checks passed, but the generator reached only 4,396 simultaneous users.
  It recorded 63,641 requests and 19,419 failures (30.51%). A 416.6-second
  event-loop interruption spanned the scheduled full-load period: no hold requests
  were measured. This run is invalid for sustained-capacity comparison; its
  418.7-second p95 must not be interpreted as ordinary server response time.
  Overload/errors were already present before the interruption. The configuration
  fix did not establish a capacity pass. The generator now explicitly fails its
  hold-error gate when there are zero hold requests instead of displaying a
  misleading zero-error percentage for an empty measurement.

**Decision: not certified for 5,000 simultaneous users or public launch.** The
query improvements and functional checks are complete; production capacity
verification remains open. Preserve both unsuccessful runs as evidence.

After testing, the disposable capacity containers and token fixtures were removed.
The normal local preview was restored with the updated backend. Web
`http://localhost:3000`, API `/api/auth/health` on port 8080 and AI `/api/v1/ready`
on port 8081 each returned HTTP 200. AI readiness does not certify live provider
inference or its capacity. The existing user database was not replaced by load data.

## Remaining launch gates

Run the same representative workload from a dedicated load-generator machine
against the intended staging infrastructure, with application replicas, PostgreSQL
and Redis given explicit resources. Record generator lag and achieved throughput;
do not disable the checks or increase timeouts simply to obtain a pass. Warm the
deployment, then sustain 5,000 users for at least 30 minutes and repeat with one
API replica unavailable. Follow with a longer soak and recovery checks.

The local short run does not cover public TLS/load balancing, real browser/mobile
mix, media throughput, AI-provider limits, group fan-out, OAuth import, backups or
database/Redis failover. Those remain separate acceptance checks on staging.
No cloud resources have been provisioned and no hosting capacity is promised.
