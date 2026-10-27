# Upload levels and retention

Admin: Settings > Storage & uploads > Manage user levels. Free is level 1 (1 GiB); Premium is level 2 (5 GiB). Add levels 3-5, save each level, and assign existing user IDs. This does not charge users or implement billing. All existing and newly registered users default to level 1.

Each level controls stored bytes, per-file bytes (up to the existing 25 MiB security ceiling), maximum finite retention (1-36,500 days), and whether never-expiring uploads are allowed. Profile photos retain their stricter 5 MiB ceiling. Generated image previews count toward storage. Settings apply to future uploads; quota reductions do not delete existing files or change existing expiry dates. A quota of zero disables uploads.

Web and mobile offer retention before uploading: never by default when allowed, otherwise a finite choice. Status/story uploads always expire in 24 hours. Multipart API clients send `retentionDays=0` for never or a positive integer. When omitted, the server uses never if permitted, otherwise the level maximum. The selected lifetime covers files in that upload. Cancellation sends no upload.

GET /api/uploads/policy returns the authenticated user's level and used bytes. ADMIN-only GET/PUT /api/admin/upload-levels lists/saves policies; PUT /api/admin/upload-levels/users/{id} with {"levelId":2} assigns a level. User-row database locks serialize quota checks across API instances. Invalid or unauthorized settings are rejected server-side.

Expired assets return HTTP 410 immediately through existing media routes. The retention job deletes up to 100 expired originals and their previews per minute; disk usage is released after deletion. Backups and previously downloaded copies follow their own retention policies. Do not expose the storage directory or private object bucket directly.

The native client source is updated; a new mobile app build must be distributed for the retention dialog. Older clients receive the same enforced server limits and default retention.

## Verification

- Backend Maven verify: 157 tests, zero failures/errors, one existing skipped test.
- Production web build passed.
- Admin settings browser checks passed on desktop and mobile (2 tests).
- Real scanned document/media uploads and seven-day retention selection passed on desktop and mobile web (2 tests).
- Flutter analyzer passed for all three changed source files; four upload validation tests and one retention-dialog widget test passed.
- Local preview restarted with migration V67 applied. No mobile release package was generated.
