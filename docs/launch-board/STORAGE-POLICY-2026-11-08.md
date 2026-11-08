# Owner-confirmed storage policy - 8 November 2026

The owner clarified in this conversation that active files must never expire automatically. When storage is full, users decide which files to delete. Initial storage is **1 GB per person**, extendable through paid plans up to **100 GB**. The existing application byte convention is retained: 1 GB = 1,073,741,824 bytes.

## Implementation

- Ordinary profile, conversation, social-post, diary and receipt uploads have no automatic expiry, including uploads from older clients that still send `retentionDays` or refer to a finite-only legacy level.
- Web and native uploads no longer display the timed-expiry chooser. Storage screens explain owner-controlled deletion and the 1 GB / 100 GB limits.
- A full quota rejects new uploads. Existing files are preserved; the application does not choose old files to delete. The same preservation rule applies after a quota reduction. Generated previews still count toward usage.
- Administrator-configured plans are limited to 100 GB and must permit non-expiring files. Existing per-file limits, malware scanning and ownership checks remain active.
- Forward migration `V72__nonexpiring_active_files.sql` clears expiry on existing undeleted files, preserving explicit story lifetimes and already-deleted records. It resets the initial Free level to 1 GB, enables never-expire on levels and caps legacy oversized levels at 100 GB. Quota reductions preserve files and can block additional uploads until users free space or change plans.
- The separate, existing temporary story/status feature still expires after 24 hours. Ordinary stored attachments do not use that lifetime.

The migration takes effect when the updated backend is deployed; it does not provision or modify a production environment by itself. It does not restore previously deleted objects.

## Payment and recovery boundaries

Storage limits can be assigned administratively. Plan prices, payment collection, paid entitlement activation and automatic subscription changes have not been specified or enabled by this policy update. No user is charged by changing a level.

The earlier ambiguous 180-day answer is no longer an active-file expiry proposal. A deleted-version recovery window is still unspecified; no 180-day recovery rule is inferred. Actual provider lifecycle, deletion and recovery acceptance under M14.6 remains open.

The October owner-input source and hashes are preserved. The profile records this clarification as a dated decision addendum in [storage-policy-2026-11-08.json](storage-policy-2026-11-08.json). Public support/privacy contact details and broader policy approvals remain outstanding.

## Verification

The first local focused run passed 14 backend quota/migration/policy/security checks. The migration regression verifies that ordinary-file expiry is cleared while stories and deleted records retain their metadata. The native non-expiring-upload widget check passed. A stronger quota assertion additionally checks that a rejected upload never deletes the existing object; final clean CI must verify the committed source. Final application build, client regressions and real-service integration results are recorded after completion.
