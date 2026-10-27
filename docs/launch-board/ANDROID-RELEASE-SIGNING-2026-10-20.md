# Android release signing implementation

Date: 20 October 2026. Launch gate: M16.4.

The release variant previously selected the Android debug signing configuration.
It now requires a separate release identity and validates the keystore, private-key
alias, key/store passwords and certificate validity before release tasks execute.
The standard Android debug alias/certificate is rejected. Debug builds still work
without release credentials.

Configure ignored `mobile/flutter-app/android/key.properties` using the example
file, or supply these environment variables (environment values take precedence):

| Variable | Value source |
|---|---|
| `MYAAPTHA_ANDROID_KEYSTORE_FILE` | Protected upload keystore file path; relative paths resolve under `android`. |
| `MYAAPTHA_ANDROID_KEYSTORE_PASSWORD` | Secret-manager store password. |
| `MYAAPTHA_ANDROID_KEY_ALIAS` | Owner upload-key alias. |
| `MYAAPTHA_ANDROID_KEY_PASSWORD` | Secret-manager key password. |

The configuration file and common keystore formats are ignored by Git. Keep keys
outside source directories and retain a secured recovery copy. This implementation
does not generate an owner's production identity or change the application ID.

The manual **Android signed release candidate** workflow uses the `android-release`
environment and four secrets: `ANDROID_UPLOAD_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`.
Configure environment reviewers and trusted release refs before using it. The
workflow builds an AAB, verifies its signature and the public upload-certificate
SHA-256 supplied at dispatch, removes the temporary private key and stores the
candidate/verification report for seven days. It does not submit to Play or approve
production promotion. No workflow was dispatched during this local development.

Offline verification:

```powershell
python infrastructure/verify_android_bundle.py candidate.aab --expected-certificate-sha256 OWNER_PUBLIC_SHA256 --output verification.json
```

The verifier requires an AAB layout, rejects duplicate/unsafe archive names, uses
the JDK signature verifier, rejects unsigned-entry/expired/rejected-algorithm
warnings and compares the signing certificate to the pinned fingerprint. It records
the AAB hash with `releaseApproved: false` and `storeSubmitted: false`. It does not
verify Play listing details, application-ID ownership, policy approval, device
acceptance or the business identity behind a certificate.

Verification includes debug-task configuration without credentials and expected
release rejection without credentials. A disposable synthetic-key release build
and negative signature/fingerprint checks passed as recorded in the current development
report. The JDK archive-reader warnings are retained in the verification JSON with
`layoutReviewRequired: true`; they require packaging/store review before acceptance. Synthetic signing artifacts are test-only and isolated under
`.tools/launch-board`; they are not owner-approved release candidates.

M16.4 remains open for the final application identity, owner upload key, Play account,
physical-device acceptance, approved disclosures and actual submission.
