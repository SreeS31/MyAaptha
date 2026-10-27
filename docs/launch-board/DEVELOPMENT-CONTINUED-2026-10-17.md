# Continued pending development — 17 October 2026

Live board: **http://127.0.0.1:4317**. This pass develops and verifies the local engineering portions of existing launch gates. It does not treat missing providers, devices, staging or policy approval as completed.

## Identity and recovery — M01.4 / M01.5

- Native registration now reads the server security policy, collects the required SMS code and submits it with the same registration contract as web.
- Policy failures block registration until retry; existing sign-in remains available. Incomplete server verification configuration fails before contacting providers or consuming verification budgets.
- The public policy now includes `phoneVerificationConfigured` and the public `phoneVerificationUrl`, with no provider credentials. Configured means server configuration is present, not that SMS delivery or the browser challenge has passed acceptance.
- Native recovery collects registered phone, SMS code and a new password, uses the shared recovery endpoint, preserves actionable failures and clears code/password fields after success. Browser verification opens externally, using the configured public web page; unsafe addresses are rejected.
- Recovery validates password composition before consuming the one-time verification code. Existing refresh sessions are revoked on a successful eligible-account reset; unknown/admin outcomes remain neutral.
- Real Twilio/Turnstile credentials, the web challenge site key, actual delivery and physical-device validation remain prerequisites. No real SMS was sent.

## Finance boundaries and input handling — M10.4

- Replaced inclusive `BETWEEN` reporting with `occurred_at >= month_start AND occurred_at < next_month_start` in UTC. A midnight transaction therefore appears in exactly one month.
- Added database tests for account isolation, month/year rollover, leap day and duplicate SMS imports; actual browser-cookie and native-bearer checks verify shared results.
- Invalid month strings return a client error. Future transaction rejection remains enabled; the first browser fixture attempted a future November transaction, correctly received 400, and was replaced with historical fixtures rather than weakening validation.
- Representative staging import acceptance remains open.

## Notification handoff — M13.3

- A webhook redirect is now a failed handoff rather than a SENT delivery. Only a 2xx provider response counts as acceptance.
- Local HTTP-server tests verify the payload, bearer header, stable idempotency key, privacy-preserving preview, retry behavior and exhausted retry budget. Provider error bodies are not persisted.
- Real channel configuration, recipient/device delivery, security-alert routing and live provider acceptance remain open. These tests use only loopback HTTP and fictitious recipients.

## Circle membership and deletion races — M06.4 / M07.6

- Verified admins-only posting and revocation of a removed member's history, search, old attachment, edit and private-deletion access. The administrator retains access to unchanged group content.
- Added concurrent read-versus-delete checks: read-first denies global deletion; delete-first leaves content redacted. Concurrent reads cannot resurrect deleted text.
- Four message-deletion/access tests passed, including the existing lifetime/role rules. Staging release acceptance remains a separate gate.

## Emergency access — M11.4

- Emergency decisions now lock the request row, preventing concurrent duplicate approvals from racing into a database error or conflicting outcomes.
- Request-list queries are scoped to the owner, requester or current Star rather than materializing every platform request.
- Eligible private attachments are filtered by the owner before applying the 100-document limit. Other accounts' newer records can no longer crowd the owner's documents out of that list.
- API responses provide viewer-specific `canDecide` and `canViewDocuments`; web/native display actions from those permissions. Current requester Star membership and access expiry are still checked by the server for each document open.
- Native now has the missing emergency-document list/open screen, reload/recheck behavior and denial cleanup. It constructs an authenticated same-API media path rather than following arbitrary document URLs. Its help explains that opening a document in another application creates a local copy which server expiry cannot recall.
- Web clears its document list and shows an error if authorization is revoked before an open.
- Three backend Trust checks, two native document-screen checks, the actual native HTTP flow and both desktop/phone-browser emergency scenarios passed. Policy approval and real owner-alert delivery remain open.

## Health input validation ? M09.1

- Activated the report DTO's existing validation constraints at the HTTP boundary, including nested measurement fields. Added a non-null requirement for each measurement row.
- Invalid dates, empty/null rows, oversized lists/fields and excessive numeric values are rejected before the service saves anything. Valid manual reports retain authenticated ownership.
- Six focused backend tests, actual native HTTP ownership/validation/deletion and both desktop/phone-browser manual entry scenarios passed. Cookie mutations without the expected CSRF headers remain rejected; rejected values are not echoed in the field error response.
- This changes manual report validation only. Provider/consent/budget acceptance for optional health analysis (M09.4) remains pending; the tests do not invoke that provider.

## Release identity preparation ? M15.8

- Added a [local build identity recorder](LOCAL-BUILD-IDENTITIES.md) for SHA-256 and byte lengths of the API JAR, Android debug APK and web build identifier. Missing artifacts cause a nonzero exit; three tests passed.
- Recorded the rebuilt local artifacts in `.tools/launch-board/build-identities.json`. Web BUILD_ID is explicitly not a digest of the full deployment bundle. The record always keeps `releaseApproved: false`.
- Signing, immutable production bundle/container identities, scans, staging acceptance and promotion approval remain pending.

## Content operations review preparation ? M08.4

- Added a [source-grounded operating draft](CONTENT-OPERATIONS-DRAFT.md) with a flow diagram, proposed role assignments, examples and a launch acceptance checklist.
- Documented reporter-visible moderator notes, the bounded queue and the distinction between changing a report status and applying an enforcement action. Named staffing, policy approval and rehearsals remain open.

## Evidence recorded so far

| Check | Result |
|---|---|
| Finance, phone recovery/configuration, webhook/lease contract | 15 backend tests passed |
| Existing authentication/invitation regression | 17 passed; API package succeeded |
| Native registration/recovery targeted checks | 7 passed |
| Native final regression including emergency documents | 44 passed; opt-in live test skipped in ordinary suite |
| Explicit native live HTTP | Passed against rebuilt API; emergency approval/document/revocation, manual health ownership/validation/deletion, account policy, UTC boundary, photo/timeline/account checks |
| Browser cookie/bearer account synchronization | Both viewport cases passed again against the final Trust/finance API build |
| Browser UTC boundary scenarios | Both viewport cases passed again against the rebuilt API; initial future fixture was corrected |
| Trust consistency and existing Trust regression | 3 passed |
| Native emergency-document screen | 2 passed |
| Message access/deletion rules and concurrency | 4 passed |
| Clean source API rebuild: recovery, finance input, Trust, message rules | 12 passed; packaged successfully |
| Emergency browser acceptance | Desktop and phone-browser passed |
| Manual health boundary/service checks | 6 passed; final API package succeeded |
| Manual health browser acceptance | Desktop and phone-browser passed; 8 browser scenarios passed across emergency, health, account and finance suites |
| Native analysis and Android debug package | Analysis clean; APK built successfully |
| Web production build | Passed; existing image optimization warnings remain |
| Local artifact identity tests | 3 passed; complete infrastructure suite 16 passed |
| Launch board browser verification | Passed; 18 modules, 86 tasks, 57 complete, 29 pending; no script errors |

Logs are in `.tools/launch-board/` with `batch2-`, `batch3-` and `batch4-` prefixes. Missing launch prerequisites are intentionally still pending on the board. Existing browser edits are preserved; restore the latest baseline only after exporting edits you want to retain.

The API was rebuilt from generated classes after incremental Maven compilation retained a stale finance controller. The clean source rebuild passed all 12 selected tests; the final health package adds the separately verified input-boundary fix, and its native/browser health checks also passed. Build identities were refreshed after that final package. No production deployment, paid model evaluation or real outbound SMS/email was performed.

## Further pending development: health analysis consent ? M09.4

Implemented the missing engineering controls: disabled-by-default server enablement, required per-report consent, additive provider/consent policy metadata, web consent gating/reset and native analysis upload controls. Native multipart requests carry the correct MIME type. Both clients skip stored-file retention prompts for this processing endpoint while keeping file/security validation.

The general provider key no longer enables health processing by itself. Manual entry remains available. Activation requires a deliberate server switch after provider/privacy/budget acceptance. See [the contract and activation workflow](HEALTH-ANALYSIS-CONSENT.md).

Verified so far in this pass: 10 backend tests; 3 new native consent/transport tests; 47 native regression tests with the opt-in live case skipped in that ordinary run; clean native analysis; API/web production builds and Android debug APK. The explicit native live case passed against the rebuilt API, including actual scanned-upload rejection while disabled and existing health/account/Trust flows. All four desktop/phone-browser consent and manual-entry scenarios passed. The updated board passed browser verification with 61/61 applicable coding checks, 65/86 testing checks and eight locally verified tasks awaiting release acceptance.

No paid extraction request was made. The browser enabled branch intercepts the processing endpoint and supplies a synthetic response. Provider quality, approved consent language/data handling, budget controls and physical-device acceptance remain open; M09.4 is not a completed launch gate.
