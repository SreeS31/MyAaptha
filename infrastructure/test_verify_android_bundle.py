import base64
import hashlib
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import Mock
from verify_android_bundle import verify


class AndroidBundleVerificationTest(unittest.TestCase):
    def fixture(self, root):
        path = root / "candidate.aab"
        with zipfile.ZipFile(path, "w") as bundle:
            bundle.writestr("BundleConfig.pb", b"synthetic")
            bundle.writestr("base/manifest/AndroidManifest.xml", b"synthetic")
        return path

    def runner(self, signature="jar verified.", cert_return=0):
        der = b"synthetic certificate parser fixture; real cryptography is checked by the JDK"
        pem = "-----BEGIN CERTIFICATE-----\n" + base64.b64encode(der).decode() + "\n-----END CERTIFICATE-----"
        return hashlib.sha256(der).hexdigest(), Mock(side_effect=[
            subprocess.CompletedProcess([], 0, signature, ""),
            subprocess.CompletedProcess([], cert_return, "Signer #1:\n" + pem, "")])

    def test_pinned_signature_records_bytes_but_never_approves_release(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = self.fixture(Path(directory)); fingerprint, runner = self.runner()
            result = verify(bundle, fingerprint.upper(), runner)
            self.assertTrue(result["signatureVerified"])
            self.assertEqual(hashlib.sha256(bundle.read_bytes()).hexdigest(), result["bundleSha256"])
            self.assertFalse(result["releaseApproved"]); self.assertFalse(result["storeSubmitted"])

    def test_wrong_certificate_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = self.fixture(Path(directory)); _, runner = self.runner()
            with self.assertRaisesRegex(ValueError,"fingerprint"): verify(bundle, "0" * 64, runner)

    def test_unsigned_entries_or_rejected_algorithms_cannot_pass_verified_message(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = self.fixture(Path(directory))
            for warning in ("unsigned entries", "treated as unsigned", "certificate has expired", "disabled algorithm", "security risk"):
                fingerprint, runner = self.runner("jar verified. Warning: " + warning)
                with self.assertRaises(ValueError): verify(bundle, fingerprint, runner)
                self.assertEqual(1, runner.call_count)

    def test_bad_certificate_tool_result_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = self.fixture(Path(directory)); fingerprint, runner = self.runner(cert_return=1)
            with self.assertRaises(ValueError): verify(bundle, fingerprint, runner)

    def test_non_bundle_and_unsafe_paths_are_rejected_before_jdk_calls(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); bundle = self.fixture(root); runner = Mock()
            with zipfile.ZipFile(bundle, "a") as archive: archive.writestr("../unexpected", b"x")
            with self.assertRaises(ValueError): verify(bundle, "0" * 64, runner)
            runner.assert_not_called()
            bundle.write_bytes(b"not a zip")
            with self.assertRaises(zipfile.BadZipFile): verify(bundle, "0" * 64, runner)

    def test_invalid_fingerprint_never_runs_external_tools(self):
        runner = Mock()
        with self.assertRaises(ValueError): verify(Path("unused.aab"), "invalid", runner)
        runner.assert_not_called()

    def test_reader_layout_warning_is_preserved_for_release_review(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = self.fixture(Path(directory)); fingerprint, runner = self.runner(
                "jar verified. This JAR file contains internal inconsistencies. Its certificate is self-signed.")
            result = verify(bundle, fingerprint, runner)
            self.assertTrue(result["layoutReviewRequired"])
            self.assertIn("jarReaderLayoutInconsistency",result["jdkWarnings"])
            self.assertFalse(result["releaseApproved"])

    def test_bundle_mutation_during_jdk_checks_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = self.fixture(Path(directory)); fingerprint, original = self.runner()
            def mutate(*args, **kwargs):
                if original.call_count == 0: bundle.write_bytes(b"replacement while signature tool was running")
                return original(*args, **kwargs)
            with self.assertRaisesRegex(ValueError,"changed during verification"):
                verify(bundle, fingerprint, mutate)


if __name__ == "__main__":
    unittest.main()
