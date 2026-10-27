# Relationship views and data security

The web dashboard offers **Family tree** (the previous default, retaining Modern/Heritage/Compact) and **Chain explorer**. Mobile offers Tree, Chain, and List. All views read `/api/network/relationships`; switching views does not copy, delete, or change relationships. The API scopes results to the authenticated owner. Mobile refresh fetches server data; offline private-response replay has been removed. The web remembers its view locally. This is shared data, not a new cross-device preference synchronization protocol.

Large network reads fetch users and profiles in batches of at most 500 IDs. A 501-person regression fixture uses two user queries and two profile queries, instead of fetching each record separately, and preserves the owner-scoped response.

## Sensitive-field encryption

The Spring Boot service uses JCA AES-256-GCM with a fresh random 96-bit nonce per value and a 128-bit authentication tag. The version and key ID are authenticated. Keys are loaded once from external configuration; no remote key-service call is made for each field. Corrupt ciphertext and unknown keys fail closed. Passwords remain one-way BCrypt hashes, not reversible encryption.

| Data | Field encryption coverage |
| --- | --- |
| Relationships | Private contact names, phones, emails, milestone/birth/death dates |
| Private person records | Nickname, phone, email, address, city, country, occupation, dates, important dates, notes |
| Managed accounts | Private biography/notes and managed birth/death dates |
| Health reports | Report name, laboratory, notes |
| Health measurements | Metric name, value, unit, reference limits, suggestions |
| Financial transactions | Amount, merchant, description |

The API still returns authorized plaintext values over TLS; web and mobile JSON contracts and decimal values are unchanged. Owner IDs, foreign keys, report/transaction dates, category and direction retain query indexes. Existing health/finance aggregation happens in Java. Arbitrary SQL sums or searches of encrypted columns are no longer supported. Encryption has CPU and storage overhead; production latency and database size must be benchmarked with representative data. This is not end-to-end encryption: the application server can decrypt these fields.

Account login identifiers (username, email, phone), searchable public profiles, messaging/social content, attachment metadata, relationship topology and audit metadata are not all field-encrypted by this change. They require database/volume/backup encryption and authorization. Private S3 objects already request server-side AES256 encryption; verify bucket policy, access controls and backup settings in the actual cloud account. The local review cannot attest to live database encryption, cloud IAM, backups or secrets. Do not describe the entire database as field-encrypted.

## Deploy existing data safely

1. Take an encrypted backup and verify restore in staging. Keep a separate recoverable copy of encryption keys in the secret manager; losing keys loses access to encrypted data.
2. Provision independently generated field and administrator-MFA keys. Each field key is exactly 32 random bytes encoded as Base64. `secrets/field_encryption_keys` contains `primary=<base64-key>`; multiple IDs use comma-separated entries. `secrets/admin_mfa_encryption_key` contains a different Base64 key. Do not reuse JWT keys, log keys, or commit secrets. Kubernetes uses `MYAAPTHA_FIELD_ENCRYPTION_KEYS` and `ADMIN_MFA_ENCRYPTION_KEY` secret entries.
3. Stop application writers during the migration window. Run the release's schema migration, including V56. It widens encrypted columns to TEXT and moves the financial amount constraint to validated application persistence because the database now stores ciphertext.
4. Run the offline `com.myaaptha.release.EncryptSensitiveFields` entry point. Compose now requires `migrate`, then `encrypt-fields`, to succeed before backend startup. Stop the existing backend before invoking Compose for this incompatible upgrade. The Kubernetes deployment script stops backend writers and autoscaling, then runs both jobs before starting the new release; it requires a verified backup reference. Jobs use the same backend image and keys as the application. Do not run them concurrently with the old application version.
5. The job processes at most 250 rows per transaction, locks selected rows, and is restartable. It encrypts legacy values and re-encrypts values using older key IDs. It prints only row counts. A failed batch rolls back; earlier batches remain committed and are skipped on restart.
6. Start the new application only after successful backfill. Production requires field encryption, rejects legacy plaintext reads, requires administrator MFA and secure cookies, and verifies database and Redis TLS. Enroll administrators before enforcing MFA. Verify authorized reads/writes and cross-user denial with staging accounts.

For rotation, retain old keys in the key ring, add a new ID, set `MYAAPTHA_FIELD_ACTIVE_KEY_ID` consistently for the job and service, and run the offline job in a maintenance window. Keep old keys for retained backups. Do not roll back to an application version that expects numeric/plaintext columns: restore the pre-migration encrypted backup and corresponding application version instead.

## Mobile and transport

Mobile tokens already use OS secure storage. Authenticated responses are no longer written to SharedPreferences; legacy `api_cache_` keys are removed on the next API read and session cleanup. Failed requests now surface errors rather than showing stale private data. Release builds require an HTTPS API URL. No new encryption keys or server decryption logic are shipped to clients.

Android backups and device-transfer extraction are disabled for app-private files, databases and preferences. Release Android manifests also reject cleartext HTTP. The web CSP permits development-only evaluation required by Next.js debugging, while production retains the strict nonce policy; see [Next.js CSP guidance](https://nextjs.org/docs/app/guides/content-security-policy).

## Validation and limits

Tests cover randomized encryption, Unicode/null/decimal round trips, tamper and wrong-key rejection, key rotation, restartable multi-batch backfill, raw database ciphertext, and owner-scoped network responses. The migration/storage tests use H2 PostgreSQL compatibility mode; verify V56 on a staging PostgreSQL database before release. Web tests cover large/cyclic tree layouts. Mobile tests were added for independent details/chain actions and removal of plaintext caching.

Local validation on 2026-09-12:

- Web production build, TypeScript check and seven unit tests passed. View-switching browser tests passed in desktop and mobile Chromium, with no page runtime errors. The build retains existing image-optimization lint warnings.
- Flutter 3.47.4 analyzer reported no issues; all eight mobile tests passed. CI is pinned to this SDK. Validation also fixed four message-write API URLs that incorrectly referenced read-pagination state.
- Full Maven `verify`: 93 tests, zero failures/errors, one skipped Redis integration test (no local Redis). Four additional adversarial authentication tests then passed with the complete 15-test authentication class: unsigned/forged tokens, browser CSRF, registration role injection, and access-token/refresh rejection after logout.
- No old-brand references remain in the scanned active project source. Windows still denies renaming the top-level project directory even after the temporary test server was stopped.
- The live npm advisory scan was not run: automatic approval review rejected sending the dependency inventory to npm, and explicit permission for that payload remains pending.

This is a security hardening pass, not a penetration-test certification or a guarantee against all attacks. No production migration or deployment was performed. A live infrastructure review, restored-backup test, current dependency advisory scan and production performance measurements remain release work.

A local Java sample of 10,000 encrypt/decrypt pairs for 232-byte text took 448.1 ms after warmup (about 45 microseconds per pair). This excludes database, network, concurrency and application overhead and is not a production latency guarantee.

Design references: [OWASP Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html), [Key Management](https://cheatsheetseries.owasp.org/cheatsheets/Key_Management_Cheat_Sheet.html), and [REST Security](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html).
