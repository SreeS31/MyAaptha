# User-selected upload expiry - 8 November 2026

This corrects the earlier same-day interpretation that forced all active files to Never. The owner explicitly requires uploaders to choose when a file expires. **Never is the default**, not the only choice.

| Choice | API `retentionDays` |
|---|---:|
| 1 day | 1 |
| 7 days | 7 |
| 30 days | 30 |
| 60 days | 60 |
| 90 days | 90 |
| 180 days | 180 |
| 1 year | 365 |
| 2 years | 730 |
| 3 years | 1095 |
| 5 years | 1825 |
| 10 years | 3650 |
| Never | 0 |

Durations are fixed 24-hour days from upload time in UTC. The same choices are returned by `GET /api/uploads/policy` as `retentionDaysOptions`, with `defaultRetentionDays: 0`. Web and native pickers use those options, default to Never, and send the selected `retentionDays` multipart field. Cancel stops the upload. Older policy responses without the additive options use the same built-in list in both clients.

The API validates the list, stores the deadline in `media_assets.expires_at` and rejects unsupported values before storing the file. Missing/blank or zero means Never. At a finite deadline downloads return 410. The bounded cleanup worker removes expired originals/previews and marks their records deleted; its default schedule is every minute. Actual removal is asynchronous and depends on the configured schedule and storage availability. Existing deletion-failure handling preserves retryability. Never and future-dated files are excluded from cleanup.

Initial storage remains **1 GB/person**, with plan limits up to **100 GB**. Quota pressure does not choose files to delete. Users may explicitly delete files or upgrade; their independently chosen expiry still applies. Plan pricing/payment activation remains unspecified. The separate temporary story/status feature retains its existing 24-hour lifespan.

## Data preservation and deployment

The unreleased V72 migration was corrected before production deployment to retain existing per-file expiry timestamps. Its quota/default-level changes remain. V73 makes all plans support Never and the full ten-year range without changing object deadlines. Earlier V72 executions in this session were confined to disposable tests; production/cloud activation was not performed. A previously cleared deadline cannot be inferred from the file itself and is not fabricated.

The earlier [storage-policy report](STORAGE-POLICY-2026-11-08.md) is superseded for expiry behavior. The original October input/hash and the current dated clarification are preserved in the owner profile and [policy record](storage-policy-2026-11-08.json). No deleted-version recovery duration, public-policy approval or release approval is inferred.

## Verification

In progress: targeted backend expiry/cleanup/migration checks, native picker and multipart payload checks, production browser selection checks and the complete GitHub CI pipeline. Results will be recorded for the final tested source commit.
