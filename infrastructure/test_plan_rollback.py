import copy
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from plan_rollback import plan
import test_render_release


class RollbackPlanTest(unittest.TestCase):
    def pair(self):
        current = test_render_release.ReleaseValidationTest().valid()
        previous = copy.deepcopy(current)
        previous["backend_image"] = "ghcr.io/myaaptha/backend@sha256:" + "b" * 64
        return current, previous

    def test_exact_image_change_is_recorded_without_approval(self):
        current, previous = self.pair()
        result = plan(current, previous)
        self.assertEqual([{"deployment": "backend", "from": current["backend_image"],
                           "to": previous["backend_image"]}], result["imageChanges"])
        self.assertFalse(result["releaseApproved"])
        self.assertFalse(result["clusterContacted"])
        self.assertEqual("unverified", result["schemaCompatibility"])
        self.assertNotEqual(result["currentConfigSha256"], result["previousConfigSha256"])
        self.assertEqual("pending", result["liveRehearsal"])

    def test_changed_data_routes_and_unknown_settings_are_rejected(self):
        for key, value in [("postgres_host", "other.myaaptha.internal"),
                           ("redis_host", "other.myaaptha.internal"),
                           ("storage_bucket", "other-private"),
                           ("unexpected_setting", "PRIVATE-DO-NOT-ECHO")]:
            current, previous = self.pair()
            previous[key] = value
            with self.assertRaises(ValueError) as caught:
                plan(current, previous)
            self.assertIn(key, str(caught.exception))
            self.assertNotIn("PRIVATE-DO-NOT-ECHO", str(caught.exception))

    def test_defaults_compare_by_effective_value_and_inputs_are_unchanged(self):
        current, previous = self.pair()
        previous.pop("db_pool_size")
        before = copy.deepcopy((current, previous))
        self.assertEqual(1, len(plan(current, previous)["imageChanges"]))
        self.assertEqual(before, (current, previous))

    def test_empty_rollback_mutable_images_and_non_objects_are_rejected(self):
        current, previous = self.pair()
        with self.assertRaises(ValueError): plan(current, current)
        previous["backend_image"] = "ghcr.io/myaaptha/backend:latest"
        with self.assertRaises(ValueError): plan(current, previous)
        with self.assertRaises(ValueError): plan([], current)

    def test_new_null_setting_still_requires_review(self):
        current, previous = self.pair()
        previous["new_setting"] = None
        with self.assertRaisesRegex(ValueError,"new_setting"): plan(current, previous)

    def test_cli_creates_reviewable_plan_and_preserves_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            current, previous = self.pair()
            a, b, output = root / "current.json", root / "previous.json", root / "plan.json"
            a.write_text(json.dumps(current)); b.write_text(json.dumps(previous))
            script = Path(__file__).with_name("plan_rollback.py")
            result = subprocess.run([sys.executable, str(script), str(a), str(b), "--output", str(output)], capture_output=True)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertFalse(json.loads(output.read_text())["releaseApproved"])
            result = subprocess.run([sys.executable, str(script), str(a), str(b), "--output", str(a)], capture_output=True)
            self.assertEqual(2, result.returncode)
            self.assertEqual(current, json.loads(a.read_text()))

    def test_cli_rejects_existing_hard_link_to_input(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            current, previous = self.pair()
            a, b, output = root / "current.json", root / "previous.json", root / "linked.json"
            a.write_text(json.dumps(current)); b.write_text(json.dumps(previous))
            try: os.link(a, output)
            except OSError as error: self.skipTest(f"Hard links unavailable: {type(error).__name__}")
            result = subprocess.run([sys.executable, str(Path(__file__).with_name("plan_rollback.py")),
                                     str(a), str(b), "--output", str(output)], capture_output=True)
            self.assertEqual(2, result.returncode)
            self.assertEqual(current, json.loads(a.read_text()))


if __name__ == "__main__":
    unittest.main()
