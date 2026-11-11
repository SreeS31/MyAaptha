# GCP beta deployment status — 11 November 2026

The beta is not live yet. This report supersedes earlier deployment status entries; it does not establish GIGW certification or complete penetration-test coverage.

## Cloud readback

Project: `project-5c36c021-87c7-4cfc-833`. The user confirmed an active trial with sufficient credit for the reviewed Mumbai beta.

- Dedicated custom VPC/subnet `myaaptha-beta`, Mumbai, `10.42.0.0/24`.
- Reserved public IP `35.244.31.192`; web ingress permits ports 80/443. SSH ingress is restricted to the IAP range.
- Private regional bucket `myaaptha-beta-media-671435485594`, uniform access and public access prevention enabled, 90-day soft delete.
- Bucket IAM readback confirms `roles/storage.objectUser` for `671435485594-compute@developer.gserviceaccount.com`. The user granted this role on the bucket through Console. No project-wide Storage Admin grant was requested.
- Synthetic object upload/read/delete/restore and content comparison succeeded using the operator account. Application access using the VM identity remains to be tested.
- No beta VM or boot disk has been created. The reserved IP can incur charges while reserved.
- `beta.myaaptha.com` still resolves to other IP addresses; DNS and a public TLS certificate remain prerequisites for that hostname.

The VM plan uses the existing Compute service account with a storage-only OAuth scope, Shielded VM settings, a 100 GB boot disk and an automatic stop after seven days. Runtime preparation generates secrets on the VM and restricts container access to its metadata credentials.

## Verification evidence

- Backend full verification: 263 tests, zero failures/errors, three skips. After the final signed-URL duration boundary correction, the focused 12-test GCS/configuration suite and packaging passed.
- Infrastructure: 96 tests passed, including scoped identity, input validation and workflow checks.
- Native GCS adapter checks cover safe metadata, missing objects, generation-pinned reads and signed-URL bounds. This replaces the unsuitable beta MinIO deployment path.
- Hardened PostgreSQL and Nginx gateway images: zero HIGH/CRITICAL findings in the recorded Trivy scans. Redis and ClamAV support images also passed that severity gate. These results are time-specific, not a guarantee of vulnerability absence.
- PostgreSQL runtime smoke passed. Gateway smoke passed with a trusted fixture TLS certificate, security headers and suppressed server banner.
- Previously recorded checks include frontend build/unit/browser tests, AI tests, Flutter tests, TLS database/cache recovery and landing-page automated accessibility checks; see the linked review for their limits.
- Source secret scanning reported zero findings. The earlier exposed local OAuth client secret still requires rotation; rotation has not been confirmed.

New application images must pass the beta CI validation and vulnerability gate before deployment. The beta image workflow now also builds and tests the hardened PostgreSQL and gateway images.

## Remaining acceptance work

Deploy immutable CI image digests to the isolated VM, configure DNS/TLS and certificate renewal, then exercise health, authentication, authorization, rate limits, antivirus uploads and native GCS read/delete using the VM identity. Check deployed firewall rules, headers, TLS and unauthenticated bucket denial.

GIGW alignment remains partial. Approved public policies, complete accessibility assessment, operational monitoring, India-based log retention, backup/DR acceptance and independent security clearance remain outstanding. Calling relay and external AI integrations require separate configured-service acceptance. Do not advertise this beta as fully audited or GIGW certified.

Related evidence: [GIGW checklist](GIGW-SECURITY-CHECK-2026-11-10.md), [security review](security-gigw-review-2026-11-10.md), [deployment guide](cloud-deployment.md).
