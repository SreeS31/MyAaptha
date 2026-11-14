# Live beta load and quality checks — 14 November 2026

Target: https://35-244-31-192.sslip.io/ on the existing GCP `myaaptha-beta` e2-standard-4 VM in `asia-south1-a`.

Result: the bounded public-traffic baseline passed. All 355 steady-load requests and 30 additional synchronized concurrency-probe requests returned HTTP 200. No accounts, messages, files or other application records were created or modified.

## Steady-load results

The test used persistent HTTPS connections from the operator's machine. Latencies include client and network overhead. The provisional acceptance thresholds were less than 1% failed requests and p95 below 1,500 ms; these are test thresholds, not a contractual service objective.

| Stage | Target requests/second | Planned duration | Requests | Failures | p95 | Maximum |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Baseline | 1 | 20 seconds | 20 | 0 | 94 ms | 203 ms |
| Moderate | 3 | 30 seconds | 90 | 0 | 94 ms | 156 ms |
| Peak | 5 | 45 seconds | 225 | 0 | 62 ms | 188 ms |
| Recovery | 1 | 20 seconds | 20 | 0 | 109 ms | 187 ms |
| Combined | — | — | 355 | 0 | 78 ms | 203 ms |

Combined median: 47 ms; p99: 156 ms. No scheduled requests were skipped, no 429 or 5xx responses occurred, and the automatic stop condition was not triggered. The load ran from 05:03:44 to 05:05:37 UTC (10:33:44–10:35:37 IST).

| Endpoint | Requests | Failures | p95 |
| --- | ---: | ---: | ---: |
| `/` | 120 | 0 | 78 ms |
| `/auth` | 61 | 0 | 47 ms |
| `/recover-account` | 58 | 0 | 94 ms |
| `/api/auth/security-policy` | 58 | 0 | 47 ms |
| `/actuator/health` | 58 | 0 | 47 ms |

The steady-load concurrency settings are upper bounds on in-flight requests, not evidence of ten continuously active users. Actual simultaneous traffic was tested separately with three synchronized bursts of ten requests to `/` and `/auth`, separated by five-second pauses. All three bursts observed ten in-flight requests. All 30 requests succeeded; combined p95 was 375 ms and maximum was 391 ms. These probes opened fresh TLS connections.

## Other checks

- All 20 live smoke checks passed: trusted TLS 1.3, HTTP-to-HTTPS redirect, public endpoint availability, HSTS, CSP, MIME/frame/referrer/permissions protections and hidden technology banners. The public certificate expires on 9 February 2027.
- Anonymous requests to `/api/auth/me`, `/api/profile/me`, `/api/social/feed` and `/api/admin/security/events` each returned 401. An untrusted CORS preflight returned 403 without an allow-origin header.
- Desktop Chromium and emulated Pixel 7 checks passed for `/`, `/auth`, `/recover-account` and `/verify-phone`: no horizontal overflow, no automated WCAG 2.1 A/AA violations, no uncaught browser errors, working sign-in navigation and visible keyboard focus. This is not a manual accessibility or GIGW certification.
- Web unit suite: 23 passed. Infrastructure regression suite: 105 passed.
- The initial desktop browser attempt failed to launch locally before visiting the website; the subsequent browser run passed. This was a test-runner failure, not a website response failure.

## Deployment and coverage limits

The live stylesheet check did **not** find the `app-visual-contract` marker from the latest unified UI release. These measurements describe the version currently running, not the pending UI release. Repeat the public checks after that rollout.

This was a short, bounded baseline. It does not establish maximum users, sustained production capacity, soak behavior, failover, authenticated feed/message/finance workloads, file-upload throughput, database contention or native-device performance. VM CPU, memory, database connections and query timings were not sampled. No production rate limit was deliberately exceeded and no authentication brute-force or destructive security testing was performed.

For a capacity decision, use a staging copy with synthetic users and representative data, instrument VM/DB/service resources, and exercise authenticated read/write journeys with increasing load and an extended soak. Avoid extrapolating public page response times into a supported-user count.

## Repeatable commands and evidence

```powershell
python infrastructure/load_test_beta.py --output .tools/beta-load-repeat.json
```

```powershell
# Run from frontend/nextjs-app. Explicit opt-in; these checks do not submit forms.
$env:MYAAPTHA_LIVE_TESTS='1'
npx.cmd playwright test --config=playwright.live.config.ts
```

Local evidence is intentionally ignored by Git: `.tools/beta-load-20261114.json`, `.tools/beta-concurrency-20261114.json`, `.tools/beta-live-smoke-20261114.json`, `.tools/beta-live-browser-20261114-final.log`, `.tools/live-beta-20261114/`, `.tools/beta-web-unit-20261114.log` and `.tools/beta-infra-tests-20261114.log`.
