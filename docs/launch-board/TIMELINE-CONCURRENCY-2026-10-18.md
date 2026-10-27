# Timeline mutation consistency

18 October 2026. Maintenance of existing timeline persistence/deletion work; no additional launch task or external acceptance is claimed.

Timeline PUT and DELETE now acquire the account's database row lock inside their existing transaction before mutating saved events. This serializes mutations for that owner across API processes. Different event keys share the same owner lock, so two new events cannot both claim the last available slot in the existing 500-event quota. Saving the same new key concurrently no longer races two independent inserts. Updates to an existing event remain permitted at the limit. Deletion/reset retains owner scope, idempotent 204 responses and unchanged source profile/relationship records.

Two new concurrency checks seed 499 synthetic events in the isolated backend database. They hold an owner lock, start two transactions and verify both wait until the lock is released. Different new keys yield one success and one quota rejection, leaving exactly 500 rows; editing an existing key still succeeds. Identical new keys both succeed with one saved row, also leaving 500 rows. Existing HTTP ownership/deletion checks remain in the targeted suite. All **17 targeted backend tests passed**, including health/trust regression, and the API package succeeded.

The lock prevents these mutation races; it does not implement editor versioning or detect stale user drafts. Same-key concurrent edits retain the last serialized write. The backend concurrency suite uses H2; the actual local PostgreSQL preview is separately exercised by ordinary browser/native shared-account flows, not a production load/concurrency certification. No schema change or web/native request contract change is required.

Evidence: `TimelineConcurrencyTest.java`, `.tools/launch-board/timeline-concurrency-api-package.log`, and the associated browser/native live logs. Production staging and representative capacity acceptance remain separately pending.
