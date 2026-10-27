import base64
import json
from pathlib import Path
import tempfile
import unittest
from preflight_release import inspect, secret_valid
from render_release import ROOT


class ReleasePreflightTests(unittest.TestCase):
    def test_missing_inputs_report_each_dependency_without_approval(self):
        with tempfile.TemporaryDirectory() as folder:
            result = inspect(Path(folder) / "missing.json", Path(folder))
        self.assertEqual(7, len(result["checks"]))
        self.assertFalse(any(check["passed"] for check in result["checks"]))
        self.assertFalse(result["releaseApproved"])
        self.assertFalse(result["externalServicesContacted"])

    def test_secret_contracts_reject_placeholders_and_malformed_keys(self):
        for name in ("jwt_secret", "postgres_password", "redis_password"):
            self.assertFalse(secret_valid(name, "replace" * 12))
            self.assertFalse(secret_valid(name, "short"))
            self.assertTrue(secret_valid(name, "ab97Qx45" * 8))
        key = base64.b64encode(bytes(range(32))).decode()
        self.assertTrue(secret_valid("admin_mfa_encryption_key", key))
        self.assertTrue(secret_valid("field_encryption_keys", "primary=" + key))
        self.assertFalse(secret_valid("field_encryption_keys", "primary=" + key + ",primary=" + key))
        self.assertFalse(secret_valid("admin_mfa_encryption_key", base64.b64encode(b"short").decode()))

    def test_report_does_not_echo_input_secrets_or_exception_values(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "secrets").mkdir()
            sentinel = "PRIVATE-SENTINEL-" * 4
            (root / "secrets/jwt_secret").write_text(sentinel)
            (root / "release.json").write_text(json.dumps({"domain": sentinel}))
            (root / "secrets/admin_mfa_encryption_key").write_text("malformed-secret")
            result = inspect(root / "release.json", root)
            self.assertNotIn(sentinel, json.dumps(result))
            self.assertNotIn("malformed-secret", json.dumps(result))
            self.assertTrue(next(c for c in result["checks"] if c["id"] == "jwt_secret")["passed"])

    def test_non_object_and_oversized_configuration_fail_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for content in ("[]", "null", "x" * 65537):
                (root / "release.json").write_text(content)
                result = inspect(root / "release.json", root)
                self.assertFalse(result["checks"][0]["passed"])

    def test_valid_local_inputs_still_do_not_grant_live_acceptance(self):
        import ssl
        from unittest.mock import patch, MagicMock
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "secrets").mkdir()
            (root / "certs").mkdir()
            config = json.loads((ROOT / "release.example.json").read_text())
            config.update(domain="app.myaaptha.test", redis_host="cache.myaaptha.internal",
                          postgres_host="db.myaaptha.internal", storage_bucket="myaaptha-private",
                          trusted_proxy_regex="10[.]0[.]1[.][0-9]{1,3}")
            for name in ("backend_image", "frontend_image", "ai_image"):
                config[name] = "ghcr.io/myaaptha/backend@sha256:" + "a" * 64
            (root / "release.json").write_text(json.dumps(config))
            key = base64.b64encode(bytes(range(32))).decode()
            for name in ("postgres_password", "redis_password", "jwt_secret"):
                (root / "secrets" / name).write_text("ab97Qx45" * 8)
            (root / "secrets/field_encryption_keys").write_text("rotated=" + key)
            (root / "secrets/admin_mfa_encryption_key").write_text(key)
            (root / "certs/postgres-ca.crt").write_text("synthetic-ca")
            context = MagicMock()
            context.cert_store_stats.return_value = {"x509_ca": 1}
            with patch.object(ssl, "SSLContext", return_value=context):
                result = inspect(root / "release.json", root, "rotated")
                self.assertTrue(result["localPrerequisitesPresent"])
                self.assertFalse(result["releaseApproved"])
                self.assertEqual("pending", result["liveAcceptance"])
                self.assertFalse(inspect(root / "release.json", root)["localPrerequisitesPresent"])
            (root / "certs/postgres-ca.crt").write_text("not-a-certificate")
            self.assertFalse(inspect(root / "release.json", root, "rotated")["checks"][-1]["passed"])


if __name__ == "__main__":
    unittest.main()
