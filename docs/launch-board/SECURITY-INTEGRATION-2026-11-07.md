# Security and integration verification - 7 November 2026

Verified source: `05b09279845555d02b7edfbc19f071d5694c43ee`, branch `feature/launch-readiness-20261027` in `SreeS31/MyAaptha`.

[GitHub CI run 42344014675](https://github.com/SreeS31/MyAaptha/actions/runs/42344014675) completed successfully. All nine jobs passed: foundation, backend, frontend, mobile, AI, three security scans and production TLS smoke. This report records results for that source commit; subsequent documentation changes do not alter the application bytes.

## Verified behavior

- Infrastructure: 82 regression tests passed locally; the GitHub foundation job passed.
- Backend: the clean Linux full invocation reported **253 tests, zero failures/errors, one skipped opt-in S3 drill**. Redis integrations ran in CI. Locally, 24 initial focused checks and 30 checks after the H2 isolation correction passed. The added HTTP test confirms unknown and duplicate JSON fields are rejected before authentication.
- Production profile: GitHub smoke passed with disposable TLS PostgreSQL and Redis against the packaged backend.
- Frontend: patched Next.js 15.5.29 production build, all **23 unit tests** and **12 desktop/phone browser tests** passed locally. GitHub frontend build/browser/unit/board verification also passed. Local standalone root and all **13 referenced static assets** returned HTTP 200 with nonce-based CSP.
- AI and mobile: their complete GitHub test jobs passed. Local native live account-sync and renewals checks both passed against the new API, real PostgreSQL and fresh ClamAV. Checks include shared account data, private scanned receipts, ownership isolation and actual in-app renewal reminders.
- Redis/OAuth: both local opt-in checks passed with authenticated disposable Redis, including separate-process state persistence. The fixture was removed.
- TLS/S3 recovery: the previously skipped drill ran separately and passed. Signed reads, unsigned-read denial, rejection of an untrusted TLS certificate, server-side encryption, versioned deletion, restore-byte equality and lifecycle-configuration round-trip were exercised. The synthetic versions and disposable object store were removed. Automatic lifecycle expiry was not measured.
- Security: all three GitHub dependency/secret scan jobs passed. Refreshed local Trivy 0.74.0 scans found zero HIGH/CRITICAL frontend production-lockfile findings and zero backend descriptor findings at any severity.
- Launch board: hosted verification passed with **zero browser script errors**, including live refresh, saved-plan preservation, acceptance guards, import/export and phone layouts. Local preview remains available at `http://127.0.0.1:4317/docs/launch-board/index.html`.

The first full local migration run exposed a shared H2 fixture shutdown problem and was stopped. Per-context UUID database names corrected isolation; the passing clean Linux full suite above is the complete post-fix result. The official Boot 4 Jackson 2 compatibility bridge preserves existing JSON contracts but is deprecated upstream; a future Jackson 3 migration requires contract verification.

## Remaining acceptance

The board remains **61 of 90 tasks recorded complete, 29 pending**. [The external launch requirements](PENDING-ACCEPTANCE-2026-11-06.md) still need cloud/DNS/provider access, staging evidence, physical device/store work, operational inputs and independent approvals. No production deployment, production data acceptance, physical-device acceptance or release approval was granted by these tests.

Raw logs, temporary credentials, caches and build binaries remain local and ignored. Refreshed local build identities fingerprint the current API and web outputs; the existing debug APK is historical and was not rebuilt or signed during this security follow-up.
