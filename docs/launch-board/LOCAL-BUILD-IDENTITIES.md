# Local build identities

Updated 18 October 2026: version 2 fingerprints the assembled web deployment files as well as the API JAR and Android debug APK, and verifies reviewed bytes have not changed.

After builds and web asset assembly finish, run from the repository root:

```powershell
python infrastructure/release_artifacts.py --output .tools/launch-board/build-identities.json
python infrastructure/release_artifacts.py --verify .tools/launch-board/build-identities.json
```

Both commands return zero only when required artifacts are present; verification additionally requires matching identities. A changed, incomplete, malformed or old version-1 record fails verification. JSON output always keeps `releaseApproved: false`.

## Web bundle coverage

The standalone directory must contain `server.js`, `package.json`, the Next.js runtime package, `.next/BUILD_ID`, public assets and `.next/static` assets. The existing local startup script assembles public/static files into the built standalone directory. Production builds should assemble the same runtime files before recording; unassembled output is incomplete.

The recorder streams each regular file into SHA-256 and records its relative path, size and digest. It sorts paths and hashes canonical JSON of the manifest for the bundle identity. File names and content matter; filesystem timestamps do not. Runtime `.next/cache/` is excluded, so serving requests does not change the deployment identity.

Missing assets, mismatched inner/outer BUILD_ID, unreadable files, links/junctions and files changing during recording fail or mark the snapshot incomplete. Output must be outside the web bundle; the recorder refuses to overwrite its own inputs. These commands do not modify application files or contact providers.

## Review and promotion limits

This fingerprint covers assembled local application files. It is not a production container digest and does not certify base images, environment, file permissions, signing, provenance, scans or staging acceptance. Android remains the debug variant.

Record immutable production image identities and approvals separately. Verify again before using recorded test evidence to promote artifacts. A rebuild requires a new identity record and appropriate validation; an old record cannot approve different bytes. Regenerate version-1 records for full bundle coverage.

This prepares M15.8 and is tracked as local engineering task M15.9. Production promotion approval remains pending.
