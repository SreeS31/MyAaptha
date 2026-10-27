"""Read-only local release prerequisites; never contact infrastructure or print secrets."""
import argparse
import base64
import json
import re
import ssl
from pathlib import Path
from render_release import validate

SECRET_FILES = ("postgres_password", "redis_password", "jwt_secret", "field_encryption_keys", "admin_mfa_encryption_key")
PLACEHOLDER = re.compile(r"replace|dummy|change-me|changethis|local-dev|example|^myaaptha123$|^admin123$", re.I)


def read_regular(path):
    if path.is_symlink() or (hasattr(path, "is_junction") and path.is_junction()):
        raise ValueError("Links are not accepted")
    if not path.is_file() or path.stat().st_size > 65536:
        raise ValueError("Missing or oversized file")
    return path.read_text(encoding="utf-8").strip()


def decode_key(value):
    return len(base64.b64decode(value, validate=True)) == 32


def secret_valid(name, value):
    if not value or PLACEHOLDER.search(value):
        return False
    if name == "admin_mfa_encryption_key":
        return decode_key(value)
    if name == "field_encryption_keys":
        pairs = [part.split("=", 1) for part in value.split(",")]
        return (all(len(pair) == 2 and re.fullmatch(r"[A-Za-z0-9_-]+", pair[0])
                    and decode_key(pair[1]) for pair in pairs)
                and len({pair[0] for pair in pairs}) == len(pairs))
    return len(value.encode("utf-8")) >= 32 if name == "jwt_secret" else len(value) >= 16


def inspect(config_path, production, active_key_id="primary"):
    checks = []
    try:
        config = json.loads(read_regular(config_path))
        if not isinstance(config, dict):
            raise ValueError("Object required")
        validate(config)
        configured = True
    except (OSError, ValueError, TypeError, OverflowError):
        config = {}
        configured = False
    checks.append({"id": "release_configuration", "passed": configured,
                   "action": "Provide a valid release JSON with immutable images, real endpoints and connection budget."})
    for name in SECRET_FILES:
        try:
            value = read_regular(production / "secrets" / name)
            passed = bool(secret_valid(name, value))
            if name == "field_encryption_keys" and passed:
                active = active_key_id
                passed = active in {part.split("=", 1)[0] for part in value.split(",")}
        except (OSError, ValueError, TypeError):
            passed = False
        checks.append({"id": name, "passed": passed,
                       "action": "Supply the protected secret file in the documented production format."})
    try:
        certificate = read_regular(production / "certs" / "postgres-ca.crt")
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.load_verify_locations(cadata=certificate)
        certificate_valid = context.cert_store_stats()["x509_ca"] > 0
    except (OSError, ValueError, ssl.SSLError):
        certificate_valid = False
    checks.append({"id": "postgres_ca", "passed": certificate_valid,
                   "action": "Supply the database provider CA trust bundle; remote hostname/expiry/connectivity still require live validation."})
    return {"schemaVersion": 1, "scope": "Local Kubernetes release JSON and Compose-mounted secret/CA prerequisites only",
            "localPrerequisitesPresent": all(check["passed"] for check in checks),
            "releaseApproved": False, "externalServicesContacted": False,
            "liveAcceptance": "pending", "checks": checks}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path)
    parser.add_argument("--production", type=Path, default=Path(__file__).parent / "production")
    parser.add_argument("--field-active-key-id", default="primary", help="Match MYAAPTHA_FIELD_ACTIVE_KEY_ID in the actual deployment.")
    args = parser.parse_args()
    result = inspect(args.config, args.production, args.field_active_key_id)
    print(json.dumps(result, indent=2))
    return 0 if result["localPrerequisitesPresent"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
