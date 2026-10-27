# Portable PostgreSQL recovery guards

18 October 2026. This is local engineering evidence for **M15.6**, which remains pending production-like recovery acceptance.

## Behavior

Backup requires an explicitly populated `DATABASE_URL` understood by PostgreSQL's client tools, rather than falling back to the operator's default database. Supply a libpq connection URL, not the application's JDBC URL. Retention must be 1–36,500 days. Each attempt gets a unique UTC timestamp/GUID name, writes a partial file, rejects failed/empty output and publishes a SHA-256 sidecar before publishing the final `.dump`. Failed attempts clean up only their generated partial/sidecar files and never prune prior backups.

After successful publication, retention removes expired regular `myaaptha-*.dump` files directly in the explicit output directory, plus their checksum sidecars. It is not recursive and skips dump symlinks/junctions. Use a dedicated backup directory and appropriately restricted filesystem permissions. Retention is a destructive operational action when this command is intentionally run; the development tests operate only in temporary fixture directories.

Restore now **requires** the `.dump.sha256.json` sidecar with a valid 64-character SHA-256 value. A missing, malformed or mismatched checksum stops before querying the target. Older trusted dumps need an independently verified checksum sidecar before use. Hashes detect accidental changes; an attacker able to replace both files is not defeated by this check.

Before restore, `psql` ignores local startup configuration and checks the target catalog for user tables, partitioned/foreign tables, views, materialized views and sequences. An unreachable or nonempty target is rejected. `pg_restore` retains `--single-transaction`, `--exit-on-error` and `--no-owner`. All three tools use `--no-password` so unattended commands fail instead of waiting for an interactive prompt; supply credentials through the approved local secret mechanism. Required PostgreSQL tools must be installed on the operator host.

Keep the target isolated from applications and other writers throughout the operation. The preflight is not a lock against another process writing later, nor a comprehensive certification that no custom routines/extensions exist. Restore only a trusted archive into a newly provisioned isolated database. Archive processing, target selection and operating permissions remain the operator's responsibility.

## Verification

Seven PowerShell command-simulation tests passed: successful unique names/checksums; failed dump cleanup without pruning; missing source/invalid retention; paired retention; checksum failures before querying; nonempty/unreachable targets; and transactional restore flags/error propagation. The complete infrastructure suite has **37 passing tests**. No simulated command opens a database connection.

The separate actual PostgreSQL 17 drill used a new disposable container, no published ports, `--network=none`, synthetic credentials and two fixture rows. The actual scripts created a custom-format dump/checksum, restored into a new empty database and matched both rows. Repeating restore into that populated target was rejected. The first drill attempt exposed a PowerShell scope error in the test adapter; that adapter was corrected and the final drill passed. The application database was never connected to this drill. Its container and anonymous database volume were removed on exit; only local synthetic backup/result evidence remains.

Reproduce locally with a cached `postgres:17-alpine` image and Docker access:

```powershell
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File testing/recovery-drill.ps1
```

Evidence: `.tools/launch-board/recovery-infrastructure-final.log`, `recovery-live-drill-final.log`, and the drill's generated `result.json`. That result explicitly records `releaseApproved: false` and `productionRecoveryVerified: false`.

This drill does not establish managed snapshots, PITR, cloud/media recovery, encrypted off-site storage, measured representative RPO/RTO or a production recovery rehearsal. Those remain M15.6/M14.6 acceptance work after staging is selected.
