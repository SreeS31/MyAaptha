"""Guard/cleanup checks for the isolated S3 drill; no Docker or network calls."""
import os
import ssl
from contextlib import contextmanager
from urllib.error import URLError
import unittest
from unittest.mock import MagicMock, patch
import smoke_s3_recovery as drill


class S3DrillSafetyTests(unittest.TestCase):
    def setup_calls(self, mapping="127.0.0.1:49123", fail=None):
        calls = []
        def execute(args, **kwargs):
            calls.append((args, kwargs))
            if args[1:3] == ["image", "inspect"]:
                return "sha256:" + "a" * 64
            if args[1] == fail:
                raise RuntimeError("Synthetic failure")
            if args[1] == "port":
                return mapping
            return "synthetic-owned-container"
        response = MagicMock()
        response.__enter__.return_value.status = 200
        return calls, execute, response

    def test_only_localhost_cached_image_and_synthetic_credentials_are_used(self):
        calls, execute, response = self.setup_calls()
        inherited = {"AWS_ACCESS_KEY_ID": "owner-key", "AWS_PROFILE": "owner-profile", "_JAVA_OPTIONS": "owner-properties"}
        with patch.dict(os.environ, inherited), patch.object(drill, "execute", side_effect=execute), patch.object(drill, "urlopen", return_value=response):
            with drill.disposable_store() as (env, image):
                self.assertEqual("sha256:" + "a" * 64, image)
                self.assertNotEqual("owner-key", env["AWS_ACCESS_KEY_ID"])
                self.assertNotIn("AWS_PROFILE", env)
                self.assertNotIn("_JAVA_OPTIONS", env)
                self.assertEqual("true", env["AWS_EC2_METADATA_DISABLED"])
                self.assertEqual("http://127.0.0.1:49123", env["MYAAPTHA_S3_DRILL_ENDPOINT"])
                self.assertEqual(env["MYAAPTHA_S3_DISPOSABLE"], env["MYAAPTHA_S3_DRILL_BUCKET"])
                create = next(args for args, _ in calls if args[1] == "create")
                self.assertIn("127.0.0.1::9000", create)
                self.assertNotIn(env["AWS_SECRET_ACCESS_KEY"], create)
                self.assertIn(image, create)
        self.assertEqual(["docker", "rm", "-f", "-v"], calls[-1][0][:4])
        self.assertRegex(calls[-1][0][-1], r"^myaaptha-s3-drill-[a-f0-9]{12}$")

    def test_create_failure_never_removes_a_container_it_did_not_create(self):
        calls, execute, _ = self.setup_calls(fail="create")
        with patch.object(drill, "execute", side_effect=execute):
            with self.assertRaises(RuntimeError):
                with drill.disposable_store():
                    self.fail("Creation must fail")
        self.assertFalse(any(args[1] == "rm" for args, _ in calls))

    def test_start_failure_cleans_only_the_created_container(self):
        calls, execute, _ = self.setup_calls(fail="start")
        with patch.object(drill, "execute", side_effect=execute):
            with self.assertRaises(RuntimeError):
                with drill.disposable_store():
                    self.fail("Startup must fail")
        self.assertEqual("rm", calls[-1][0][1])

    def test_non_loopback_mapping_is_rejected_and_cleaned(self):
        calls, execute, _ = self.setup_calls(mapping="0.0.0.0:49123")
        with patch.object(drill, "execute", side_effect=execute):
            with self.assertRaises(ValueError):
                with drill.disposable_store():
                    self.fail("Non-loopback service must be rejected")
        self.assertEqual("rm", calls[-1][0][1])

    def test_body_failure_still_cleans_created_service(self):
        calls, execute, response = self.setup_calls()
        with patch.object(drill, "execute", side_effect=execute), patch.object(drill, "urlopen", return_value=response):
            with self.assertRaisesRegex(ValueError, "body"):
                with drill.disposable_store():
                    raise ValueError("body failure")
        self.assertEqual("rm", calls[-1][0][1])

    def test_cleanup_failure_cannot_report_success(self):
        _, execute, response = self.setup_calls(fail="rm")
        with patch.object(drill, "execute", side_effect=execute), patch.object(drill, "urlopen", return_value=response):
            with self.assertRaises(RuntimeError):
                with drill.disposable_store():
                    pass

    def test_malformed_image_identity_fails_before_creation(self):
        with patch.object(drill, "execute", return_value="sha256:" + "z" * 64) as execute:
            with self.assertRaises(ValueError):
                with drill.disposable_store():
                    self.fail("Malformed identity must fail")
        self.assertEqual(1, execute.call_count)

    def test_unhealthy_service_times_out_and_is_cleaned(self):
        calls, execute, _ = self.setup_calls()
        with patch.object(drill, "execute", side_effect=execute), patch.object(drill, "urlopen", side_effect=OSError), patch.object(drill.time, "sleep"):
            with self.assertRaisesRegex(RuntimeError, "ready"):
                with drill.disposable_store():
                    self.fail("Unhealthy service must fail")
        self.assertEqual("rm", calls[-1][0][1])

    def test_tls_wiring_uses_readonly_certificates_and_requires_untrusted_rejection(self):
        calls, execute, response = self.setup_calls()
        trusted = object()
        @contextmanager
        def material(enabled):
            self.assertTrue(enabled)
            yield {"MINIO_KMS_SECRET_KEY": "synthetic-only", "JAVA_TOOL_OPTIONS": "synthetic-trust"}, ["-v", "synthetic-certs:/certs:ro"], trusted
        rejection = URLError(ssl.SSLCertVerificationError("synthetic untrusted certificate"))
        with patch.object(drill, "local_tls", material), patch.object(drill, "execute", side_effect=execute), patch.object(drill, "urlopen", side_effect=[response,rejection]) as request:
            with drill.disposable_store(True) as (env, _):
                self.assertTrue(env["MYAAPTHA_S3_DRILL_ENDPOINT"].startswith("https://127.0.0.1:"))
                self.assertEqual("true", env["MYAAPTHA_S3_DRILL_UNTRUSTED_TLS_REJECTED"])
                self.assertIs(trusted, request.call_args_list[0].kwargs["context"])
                create=next(args for args, _ in calls if args[1] == "create")
                self.assertIn("--certs-dir", create)
                self.assertIn("synthetic-certs:/certs:ro", create)
                self.assertIn("MINIO_KMS_SECRET_KEY", create)
                self.assertNotIn("synthetic-only", create)

    def test_tls_accepting_untrusted_certificate_fails_and_cleans_up(self):
        calls, execute, response = self.setup_calls()
        @contextmanager
        def material(enabled):
            yield {}, [], object()
        with patch.object(drill, "local_tls", material), patch.object(drill, "execute", side_effect=execute), patch.object(drill, "urlopen", return_value=response):
            with self.assertRaisesRegex(RuntimeError, "unexpectedly accepted"):
                with drill.disposable_store(True):
                    self.fail("Untrusted certificate must fail")
        self.assertEqual("rm", calls[-1][0][1])


if __name__ == "__main__":
    unittest.main()
