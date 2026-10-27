"""Verify a local AAB signature and pinned public certificate; never upload it."""
import argparse
import hashlib
import json
import re
import ssl
import subprocess
import zipfile
from pathlib import Path, PurePosixPath


def verify(bundle, expected_certificate, runner=subprocess.run):
    expected = expected_certificate.replace(":", "").lower()
    if not re.fullmatch(r"[a-f0-9]{64}", expected):
        raise ValueError("Expected certificate must be a SHA-256 fingerprint")
    before = bundle.stat()
    with zipfile.ZipFile(bundle) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or any(name.startswith("/") or ".." in PurePosixPath(name).parts for name in names):
            raise ValueError("Bundle has duplicate or unsafe entry names")
        if not {"BundleConfig.pb", "base/manifest/AndroidManifest.xml"}.issubset(names):
            raise ValueError("Expected an Android App Bundle")
    language = ["-J-Duser.language=en", "-J-Duser.country=US"]
    signature = runner(["jarsigner", *language, "-verify", str(bundle)], capture_output=True, text=True, timeout=120)
    output = (signature.stdout + signature.stderr).lower()
    if signature.returncode or "jar verified." not in output or any(message in output for message in
            ("unsigned entr", "jar is unsigned", "treated as unsigned", "expired", "disabled", "security risk")):
        raise ValueError("Bundle signature is invalid, incomplete, expired or uses a rejected algorithm")
    certificate = runner(["keytool", *language, "-printcert", "-rfc", "-jarfile", str(bundle)], capture_output=True, text=True, timeout=120)
    blocks = re.findall(r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", certificate.stdout, re.S)
    if certificate.returncode or not blocks or len(re.findall(r"Signer #\d+", certificate.stdout)) > 1:
        raise ValueError("Expected exactly one signing identity")
    fingerprint = hashlib.sha256(ssl.PEM_cert_to_DER_cert(blocks[0])).hexdigest()
    if fingerprint != expected:
        raise ValueError("Bundle certificate does not match the expected owner fingerprint")
    with bundle.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    after = bundle.stat()
    if (before.st_size, before.st_mtime_ns, before.st_ino) != (after.st_size, after.st_mtime_ns, after.st_ino):
        raise ValueError("Bundle changed during verification; finish the build and retry")
    warnings = [label for phrase, label in (
        ("self-signed", "selfSignedCertificate"),
        ("do not include a timestamp", "noTimestamp"),
        ("will expire within", "certificateExpiresSoon"),
        ("internal inconsistencies", "jarReaderLayoutInconsistency"),
        ("attributes are ignored", "zipAttributesNotSigned"),
    ) if phrase in output]
    return {"signatureVerified": True, "certificateSha256": fingerprint,
            "bundleSha256": digest, "jdkWarnings": warnings,
            "layoutReviewRequired": "jarReaderLayoutInconsistency" in warnings,
            "releaseApproved": False, "storeSubmitted": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--expected-certificate-sha256", required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        if args.output and (args.output.resolve() == args.bundle.resolve() or
                            args.output.exists() and args.output.samefile(args.bundle)):
            raise ValueError("Verification output must not overwrite the bundle")
        result = verify(args.bundle, args.expected_certificate_sha256)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    except (OSError, ValueError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
        parser.exit(2, f"Bundle verification rejected: {error}\n")
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
