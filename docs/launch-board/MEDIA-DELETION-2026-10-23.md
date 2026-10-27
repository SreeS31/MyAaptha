# Media deletion reliability - 23 October 2026

Local object storage previously swallowed IOExceptions during deletion. The service could then save deletedAt and release quota even though removal failed. Local storage now raises a server error, matching the failure propagation of the S3 adapter. The service does not mark the asset deleted when original or preview removal fails; subsequent attempts can retry, including when the original is already absent.

Validation: MediaDeletionTest, MediaPlatformTest and ClamAvMediaScannerTest: 9 tests passed, zero failures/errors/skips. A disposable nonempty-directory fixture proves real filesystem failure propagation and retry without relying on OS permission behavior. Service tests cover original failure and preview failure followed by retry. Log: .tools/launch-board/media-deletion-20261023.log.

This is source-level engineering evidence. The running preview has not been rebuilt or restarted for this change. No API schema or client contract changed. S3 versioned deletion still retains noncurrent versions until approved lifecycle or purge policy; this change does not certify permanent erasure, production retention, or release acceptance. M14.6 remains pending.
