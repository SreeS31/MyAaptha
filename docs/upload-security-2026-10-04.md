# Upload security and administration

General attachments support PDF, DOCX, XLSX, PPTX, TXT/CSV/vCard, supported images, audio (including MP3), video (including MP4), and existing supported 3D formats. Profile photos and diagnostic reports keep their purpose-specific restrictions. Legacy DOC/XLS/PPT, macro documents, executables, scripts, SVG/HTML and general archives are intentionally not accepted. Convert older Office files to the macro-free modern format first.

## Protection

- Web preflight checks every FormData request and every upload with progress; file inputs also check filenames/extensions and size. Mobile's shared multipart client validates filenames, size and key signatures. These are feedback checks, not antivirus guarantees.
- All multipart API endpoints pass through a shared scanner, including Spring security-wrapped requests. Storage independently checks again before permanent save. File size is limited to 25 MiB; multipart requests to 30 MiB and 10 files. Two simultaneous interceptor scans per API instance bound scan memory; existing request-capacity protection also applies.
- Server checks include extension allowlists, blocked double extensions, MIME and common signatures, executable/EICAR signatures, active PDF content, and bounded ZIP/Office inspection. Unsafe macro/embedded entries are rejected. Image thumbnail dimensions are checked before decoding.
- ClamAV is now the default. Production configuration refuses non-ClamAV scanning. Scanner errors and signatures older than 48 hours reject uploads with 503; files are not permanently saved or shared. No fallback silently accepts an unscanned file. The scanner service is private; local port 53310 binds only to loopback.
- Server scanning necessarily receives bytes in bounded private multipart temporary storage first. It cannot scan bytes it has not received. This is distinct from publishing/permanently storing approved attachments. No antivirus guarantees that every unknown exploit is detected.
- Upload budgets: 20 per authenticated subject/minute and 60 per IP/minute, in addition to existing general rate and capacity limits. Production gateway also caps API request bodies at 30 MB.

## Incidents and blocks

`/security-reports` and `/api/admin/security/**` are ADMIN-only. Reports include rejected uploads, scanner failures and API server errors (5xx), time, route template, account ID, source IP, block expiry and email delivery state. File contents, request bodies, passwords and arbitrary exception text are not included. Ordinary unsupported files do not imply malicious intent and do not ban users. Positive antivirus/executable test signatures trigger a one-hour IP block. Authenticated administrators retain access to the report API and their identity endpoint to review/unblock. The server uses its resolved remote address, never an untrusted forwarded header; production must configure the precise trusted proxy addresses and restrict direct origin access.

Blocks use shared Redis in production and are restored from active database incidents on application startup. Local preview uses its existing development state implementation. Admins can mark incidents reviewed or unblock an IP. Reports are retained for 90 days; repeated events of the same category/IP within five minutes are deduplicated. Shared IPs can include innocent users: temporary blocks and manual review are deliberate.

## Email setup still required

Set these in the backend process environment/deployment secret manager, then restart the backend:

```
MYAAPTHA_SECURITY_ADMIN_EMAIL=your-admin-address
MYAAPTHA_NOTIFICATION_WEBHOOK_CHANNEL=EMAIL
MYAAPTHA_NOTIFICATION_WEBHOOK_URL=https://your-email-delivery-provider-endpoint
MYAAPTHA_NOTIFICATION_WEBHOOK_TOKEN=your-provider-token
```

Use the existing application email webhook contract: JSON `channel`, `destination`, `title`, `body`, `actionUrl`, with Bearer authentication and an `Idempotency-Key`. The endpoint must deliver the requested email; this is not an SMTP hostname. The security report link is relative (`/security-reports`), so the provider/template should prepend the application's public origin.

Alerts stay PENDING when the recipient/provider is missing. The queue processes at most five per minute, retries failures up to five attempts at five-minute intervals and records SENT/FAILED. It uses a distinct idempotency key namespace to avoid duplicate delivery during retries. No real emails were sent by the tests.

## Deployment and limits

Local startup includes ClamAV and its persistent signature volume. Production Compose includes a private ClamAV service and backend dependency; pin CLAMAV_IMAGE to a reviewed image digest for deployment. Maintain signature updates, monitor scanner availability, and reserve antivirus memory. These code changes do not deploy a public WAF/CDN or prove resistance to volumetric DDoS attacks. Put the public site behind managed DDoS/WAF protection and firewall the origin to trusted proxies. Client validation, rate limiting and antivirus are complementary controls, not a claim that hacking is impossible.

Browser/mobile UI crashes and host/CDN errors are not automatically captured as API 5xx incidents; infrastructure monitoring remains necessary. Existing user moderation reports continue separately.

## Verification

- Backend full verify: 146 tests, no failures/errors, one existing skipped test.
- Three separate email queue tests passed (no real delivery).
- Web upload unit tests: two passed.
- Flutter API validation: four passed.
- Admin reports browser layout: desktop and mobile passed.
- Production web build, production Compose validation and gateway configuration validation passed.
- Actual antivirus-backed TXT/PDF/MP3/MP4 API uploads and DOCX chat uploads: desktop and mobile browser tests passed.

Evidence: `.tools/upload-backend-verify.log`, `.tools/security-alert-tests.log`, `.tools/upload-client-tests.log`, `.tools/upload-mobile-tests.log`, `.tools/security-reports-browser.log`, `.tools/upload-web-build.log`, `.tools/secure-upload-browser.log`, `.tools/upload-gateway-validation.log`.

References: [OWASP File Upload guidance](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html), [ClamAV Docker documentation](https://docs.clamav.net/manual/Installing/Docker.html), [Caddy request body limits](https://caddyserver.com/docs/caddyfile/directives/request_body).
