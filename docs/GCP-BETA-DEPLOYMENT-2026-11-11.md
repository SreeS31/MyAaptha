# GCP beta deployment status — 11 November 2026

**The beta is live at https://35-244-31-192.sslip.io/.** See the [final live verification](LIVE-BETA-VERIFICATION-2026-11-11.md) for passed checks and remaining GIGW gaps. Earlier pending/blocker entries below record deployment history and are superseded by that final result. This does not establish GIGW certification or complete penetration-test coverage.

## Cloud readback

Project: `project-5c36c021-87c7-4cfc-833`. The user confirmed an active trial with sufficient credit for the reviewed Mumbai beta.

- Dedicated custom VPC/subnet `myaaptha-beta`, Mumbai, `10.42.0.0/24`.
- Reserved public IP `35.244.31.192`; web ingress permits ports 80/443. SSH ingress is restricted to the IAP range.
- Private regional bucket `myaaptha-beta-media-671435485594`, uniform access and public access prevention enabled, 90-day soft delete.
- Bucket IAM readback confirms `roles/storage.objectUser` for `671435485594-compute@developer.gserviceaccount.com`. The user granted this role on the bucket through Console. No project-wide Storage Admin grant was requested.
- Synthetic object upload/read/delete/restore and content comparison succeeded using the operator account. Subsequent live application upload, byte-for-byte read and delete succeeded using the VM identity.
- The beta VM is running in `asia-south1-a`: `e2-standard-4`, 100 GB preserved boot disk, public IP `35.244.31.192`, Secure Boot/vTPM/integrity monitoring enabled. Readback confirms storage-only OAuth scope. The user subsequently requested at least 30 days: automatic STOP is now configured after 2592000 seconds, expected 11 December 2026 at 22:40 IST. The VM, disk and public IP consume trial credit. See the final report for the separate private-certificate maintenance deadline.
- `beta.myaaptha.com` still resolves to other IP addresses; DNS and a public TLS certificate remain prerequisites for that hostname.

The VM uses the existing Compute service account. Runtime preparation generated secrets on the VM and installed container metadata credential restrictions. The approved image metadata was supplied, the network repair completed, all runtime services reported healthy and certificate renewal simulation succeeded.

## Verification evidence

- Backend full verification: 263 tests, zero failures/errors, three skips. After the final signed-URL duration boundary correction, the focused 12-test GCS/configuration suite and packaging passed.
- Infrastructure: 96 tests passed, including scoped identity, input validation and workflow checks.
- Native GCS adapter checks cover safe metadata, missing objects, generation-pinned reads and signed-URL bounds. This replaces the unsuitable beta MinIO deployment path.
- Hardened PostgreSQL and Nginx gateway images: zero HIGH/CRITICAL findings in the recorded Trivy scans. Redis and ClamAV support images also passed that severity gate. These results are time-specific, not a guarantee of vulnerability absence.
- PostgreSQL runtime smoke passed. Gateway smoke passed with a trusted fixture TLS certificate, security headers and suppressed server banner.
- Previously recorded checks include frontend build/unit/browser tests, AI tests, Flutter tests, TLS database/cache recovery and landing-page automated accessibility checks; see the linked review for their limits.
- Source secret scanning reported zero findings. The earlier exposed local OAuth client secret still requires rotation; rotation has not been confirmed.

New application images must pass the beta CI validation and vulnerability gate before deployment. The beta image workflow now also builds and tests the hardened PostgreSQL and gateway images.

The first release attempt, commit `fe7b2c9` / tag `beta-20261111-gcp-r1`, was blocked by the backend security gate. Local reproduction found HIGH `CVE-2026-102554` in transitive Guava `33.6.0-jre`. The backend now manages Guava at `33.7.2-jre`, containing the [upstream fix](https://github.com/google/guava/releases/tag/v33.7.2). The focused 12 tests and packaging passed; the subsequent backend filesystem vulnerability/secret scan returned exit code 0, zero HIGH/CRITICAL findings and zero secrets. Replacement CI validation remains required; the failed release must not be used.

The user selected `35-244-31-192.sslip.io` as the initial HTTPS beta hostname. The custom production DNS has not been changed.

The second attempt's backend CI scanner also failed while local Trivy 0.74 reported clean. CI is now pinned to the same tested scanner version, explicitly limits SARIF to the configured HIGH/CRITICAL gate, and publishes vulnerability-only annotations for diagnosis without exposing matched secrets. Replacement validation is pending.

### Approved release and current blocker

Replacement tag `beta-20261111-gcp-r3`, commit `ceb4dc7250aa9ef4ad586eb0294a71789a40f93d`, passed [all beta CI jobs](https://github.com/SreeS31/MyAaptha/actions/runs/42950871197), including backend/frontend/mobile/AI tests, infrastructure tests, production TLS smoke and five image build/runtime/security gates. All five GHCR images are anonymously pullable by digest. The seven-image deployment map is [beta-images-20261111.json](../infrastructure/production/beta-images-20261111.json); Redis and ClamAV retain the separately scanned digests.

The connected GCP command service rejects both `gcloud compute instances add-metadata` and `gcloud compute ssh` as unsupported. Therefore the digest map has not reached the VM. In Compute Engine, open VM `myaaptha-beta`, choose **Edit**, locate **Custom metadata**, and add key `beta-images` with the entire JSON deployment map as its value. Save without changing the existing startup script or security settings. The startup script polls for this metadata for 45 minutes after host setup. If it has already expired, inspect the startup log before restarting the bootstrap; the application is still not live.

External isolation checks returned HTTP 403 for the unauthenticated synthetic GCS object request. Public TCP connection attempts to SSH 22, PostgreSQL 5432, Redis 6379, backend 8080 and AI 8081 were not reachable. This is a limited exposure check, not a comprehensive port scan or a test of internal service identity.

### Metadata confirmed and network repair

The user saved `beta-images`; readback matches all seven approved digests. The initial 45-minute startup wait had already expired, so the VM was restarted. Runtime secrets and private database/cache certificates were generated on the VM, and a public certificate was successfully issued for `35-244-31-192.sslip.io`.

Container startup then failed because dynamically addressed dependencies consumed addresses reserved for frontend/backend/gateway. The corrected Compose IPAM reserves `172.30.0.128/25` for dynamic allocation, leaving the fixed `.2`, `.3` and `.4` addresses separate. A disposable Docker reproduction started five dynamic containers first and then all three static containers successfully; 97 infrastructure tests passed, including a regression check of this invariant.

`infrastructure/repair_gcp_beta_network.py` verifies the exact beta host/project and known prior runtime configuration before replacing only the affected Compose file. It recreates the Compose network without removing volumes or changing secrets/certificates, starts the existing approved images, and verifies certificate renewal. Applying this repair remains pending because the connector cannot change startup metadata or run SSH. The application is not yet live.

## Remaining acceptance work

Deploy immutable CI image digests to the isolated VM, configure DNS/TLS and certificate renewal, then exercise health, authentication, authorization, rate limits, antivirus uploads and native GCS read/delete using the VM identity. Check deployed firewall rules, headers, TLS and unauthenticated bucket denial.

GIGW alignment remains partial. Approved public policies, complete accessibility assessment, operational monitoring, India-based log retention, backup/DR acceptance and independent security clearance remain outstanding. Calling relay and external AI integrations require separate configured-service acceptance. Do not advertise this beta as fully audited or GIGW certified.

Related evidence: [GIGW checklist](GIGW-SECURITY-CHECK-2026-11-10.md), [security review](security-gigw-review-2026-11-10.md), [deployment guide](cloud-deployment.md).
