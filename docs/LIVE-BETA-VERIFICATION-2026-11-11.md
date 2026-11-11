# Live beta verification — 11 November 2026

**Live beta:** https://35-244-31-192.sslip.io/

The Mumbai beta is running with trusted HTTPS. The VM reported all services healthy and successful certificate-renewal simulation at 22:27 IST on 11 November 2026. This supersedes the earlier pending-deployment entries in the deployment report. The custom `beta.myaaptha.com` DNS was not changed.

## Release and deployment

The application images are from commit `ceb4dc7250aa9ef4ad586eb0294a71789a40f93d`, tag `beta-20261111-gcp-r3`. [All beta CI jobs passed](https://github.com/SreeS31/MyAaptha/actions/runs/42950871197), including application tests, production TLS smoke and five image build/runtime/security gates. The immutable image map is [beta-images-20261111.json](../infrastructure/production/beta-images-20261111.json).

An initial static/dynamic Docker address collision was corrected in commit `c9229fd`. The new dynamic pool excludes the three reserved service addresses. A disposable eight-container reproduction passed; all 97 infrastructure tests passed. The user installed the pinned repair startup script through Console because the connected GCP service does not support metadata updates or SSH. Readback matched the script and approved image map before restart. The repair preserved existing secrets, certificates and volumes and reported successful completion.

## Live checks passed

| Area | Observed result |
| --- | --- |
| Application readiness | Landing page responds; public health reports UP without component details. All runtime services reported healthy; migration/encryption jobs completed. |
| TLS and renewal | Trusted certificate; TLS 1.2 and 1.3 accepted with AES-256-GCM ciphers. TLS 1.0 and 1.1 rejected with protocol-version alerts. Certificate renewal dry run and gateway reload hook succeeded. |
| Browser protection | CSP, HSTS, nosniff and DENY frame headers present; Server and X-Powered-By headers absent. HTTP redirects to the fixed HTTPS beta host even with hostile Host/forwarded headers. |
| Sessions and CSRF | Login/refresh work. Browser cookies use __Host-, Secure, HttpOnly, SameSite=Strict, Path=/ and no Domain. Session responses use no-store and omit access/refresh tokens. Missing mutation header and untrusted Origin rejected; cookie authentication, refresh and logout verified. |
| Authorization | Anonymous protected API and forged token rejected. Member access to administrator user listing denied. Cross-user circle access and private-media access denied. Financial records enforce ownership; authorized cleanup succeeds. |
| Private GCS | Synthetic private PNG uploaded through the real antivirus-gated API, downloaded byte-for-byte through the authenticated application and deleted. This exercises native GCS with the VM identity. Another account could not fetch the private attachment. |
| Exposure | Public connection attempts to TCP 22, 5432, 6379, 8080 and 8081 were not reachable. An anonymous synthetic GCS object request returned 403 in the recorded isolation check. |
| Accessibility | Live landing-page axe WCAG 2.1 A/AA checks returned zero violations on desktop and mobile; no horizontal overflow. This covers the landing page only. |

Synthetic accounts and one test circle remain for audit. The synthetic financial transaction and private attachment were deleted. No customer data was used. Raw reports and public-page screenshots are retained under ignored `.tools/live-beta-*` files, without session tokens or passwords.

## Limits and remaining GIGW work

This is an operational beta and a bounded security verification, not a complete independent penetration test or GIGW/STQC certification. Local tests and source review supply additional evidence in the [GIGW checklist](GIGW-SECURITY-CHECK-2026-11-10.md). Clean scans are time-specific and do not establish absence of vulnerabilities.

Outstanding acceptance includes approved privacy/content/security policies, authenticated-screen and manual assistive-technology accessibility assessment, independent security clearance, monitoring/alert delivery, 180-day India-based log retention, scheduled backups and application-level disaster-recovery acceptance. Some internal application hops use HTTP. External AI providers, calling relay and physical mobile workflows require configured-service acceptance; this deployment does not establish that those integrations work. Rotation of the OAuth client secret exposed in an earlier local diagnostic remains unconfirmed.

At the user's request, the VM automatic-stop policy was extended from seven to **30 days**. GCP readback confirms `maxRunDuration.seconds=2592000`, termination action `STOP` and status `RUNNING`. The new start timestamp gives an expected automatic stop of **11 December 2026 at 22:40 IST**. A brief stop/start was required by GCP to change this setting; trusted HTTPS landing, API health UP and anonymous API denial passed afterward. The temporary hostname remains in use while the user confirms a custom domain.

Maintenance is required before the end of that period: the private PostgreSQL/Redis certificates were initially issued with a 30-day lifetime on 11 November, before this restart, and must be renewed **before 11 December 2026** to avoid internal TLS failures. Extending the VM runtime does not renew these certificates. The separate public HTTPS certificate has a verified automatic renewal path. Trial credit continues to be consumed; retained disk and public IP can continue consuming credit after compute stops. This is not a production availability or spending-cap guarantee.
