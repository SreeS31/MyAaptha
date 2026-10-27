import hashlib
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from release_artifacts import ARTIFACTS, WEB_BUNDLE, matches, snapshot


def fixture(root):
    for relative in ARTIFACTS.values():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"fixture-build\n")
    for relative in ("server.js", "package.json", ".next/BUILD_ID", "node_modules/next/package.json", "public/icon.svg", ".next/static/chunk.js"):
        path = root / WEB_BUNDLE / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"fixture-build\n")


class ArtifactSnapshotTests(unittest.TestCase):
    def test_missing_builds_are_explicit_and_never_approved(self):
        with tempfile.TemporaryDirectory() as directory:
            result = snapshot(Path(directory))
            self.assertFalse(result["allPresent"])
            self.assertFalse(result["releaseApproved"])
            self.assertTrue(all(not item["present"] for item in result["artifacts"]))

    def test_hashes_exact_artifact_bytes_and_records_web_identifier(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root)
            result = snapshot(root)
            self.assertTrue(result["allPresent"])
            self.assertFalse(result["releaseApproved"])
            for item in result["artifacts"]:
                self.assertEqual(item["sha256"], hashlib.sha256(b"fixture-build\n").hexdigest())
                self.assertEqual(item["sizeBytes"], 14)
            self.assertEqual(result["artifacts"][1]["buildId"], "fixture-build")

    def test_rebuilt_bytes_change_the_recorded_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifact = root / ARTIFACTS["api"]
            artifact.parent.mkdir(parents=True)
            artifact.write_bytes(b"first")
            first = snapshot(root)["artifacts"][0]["sha256"]
            artifact.write_bytes(b"second")
            self.assertNotEqual(first, snapshot(root)["artifacts"][0]["sha256"])

    def test_bundle_changes_detected_with_unchanged_build_id(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root)
            record = snapshot(root)
            self.assertTrue(matches(record, snapshot(root)))
            (root / WEB_BUNDLE / ".next/static/chunk.js").write_text("changed chunk")
            self.assertFalse(matches(record, snapshot(root)))

    def test_paths_are_part_of_the_identity_and_runtime_cache_is_excluded(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root)
            record = snapshot(root)
            cache = root / WEB_BUNDLE / ".next/cache/runtime.txt"
            cache.parent.mkdir(parents=True)
            cache.write_text("runtime-only")
            self.assertTrue(matches(record, snapshot(root)))
            asset = root / WEB_BUNDLE / "public/icon.svg"
            os.utime(asset, (1, 1))
            self.assertTrue(matches(record, snapshot(root)))
            asset.rename(asset.with_name("renamed.svg"))
            self.assertFalse(matches(record, snapshot(root)))

    def test_missing_static_files_and_mismatched_build_ids_are_incomplete(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root)
            (root / WEB_BUNDLE / ".next/BUILD_ID").write_text("stale")
            self.assertFalse(snapshot(root)["allPresent"])
            (root / WEB_BUNDLE / ".next/static/chunk.js").unlink()
            self.assertIn(".next/static/", snapshot(root)["webBundle"]["missing"])

    def test_verification_never_accepts_old_or_approval_claiming_records(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root)
            record = snapshot(root)
            self.assertFalse(matches([], record))
            self.assertFalse(matches({"schemaVersion": 1}, record))
            record["releaseApproved"] = True
            self.assertFalse(matches(record, snapshot(root)))

    def test_bundle_links_are_rejected_without_reading_target_contents(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root)
            outside = root / "outside.txt"
            outside.write_text("private fixture")
            try:
                (root / WEB_BUNDLE / "public/link.txt").symlink_to(outside)
            except OSError:
                self.skipTest("This host cannot create symlinks without additional privileges.")
            with self.assertRaisesRegex(ValueError, "link/junction"):
                snapshot(root)

    def test_cli_detects_changed_bytes_and_cannot_overwrite_the_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root)
            script = str(Path(__file__).with_name("release_artifacts.py"))
            record = root / "identities.json"
            def run(*args):
                return subprocess.run([sys.executable, script, "--root", str(root), *args], capture_output=True, text=True)
            self.assertEqual(run("--output", str(record)).returncode, 0)
            self.assertEqual(run("--verify", str(record)).returncode, 0)
            target = root / WEB_BUNDLE / "package.json"
            original = target.read_bytes()
            self.assertEqual(run("--output", str(target)).returncode, 2)
            self.assertEqual(target.read_bytes(), original)
            (root / WEB_BUNDLE / "public/icon.svg").write_text("changed asset")
            rejected = run("--verify", str(record))
            self.assertEqual(rejected.returncode, 1)
            self.assertIn('"matches": false', rejected.stdout)


if __name__ == "__main__":
    unittest.main()
