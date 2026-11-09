"""Guard recovery templates against silently expiring active/Never uploads."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class MediaRecoveryPolicyTests(unittest.TestCase):
    def test_lifecycle_only_expires_noncurrent_versions(self):
        policy = json.loads((ROOT / 'infrastructure/production/media-lifecycle.json').read_text())
        self.assertTrue(policy['Rules'])
        for rule in policy['Rules']:
            self.assertEqual(set(rule), {'ID', 'Status', 'Filter', 'NoncurrentVersionExpiration'})
            self.assertEqual(rule['Status'], 'Enabled')
            # Do not retain a fixed number indefinitely or filter out older versions.
            self.assertEqual(rule['NoncurrentVersionExpiration'], {'NoncurrentDays': 90})
            self.assertEqual(rule['Filter'], {'Prefix': ''})

    def test_owner_contract_and_template_agree_without_changing_active_expiry(self):
        folder = ROOT / 'docs/launch-board'
        decision = json.loads((folder / 'recovery-policy-2026-11-09.json').read_text())
        storage = json.loads((folder / 'storage-policy-2026-11-08.json').read_text())
        self.assertEqual(decision['deletedVersionRecoveryDays'], 90)
        self.assertEqual(storage['deletedVersionRecoveryDays'], 90)
        self.assertFalse(decision['productionConfigured'])
        self.assertFalse(decision['recoveryAccepted'])
        self.assertEqual(storage['defaultRetentionDays'], 0)
        self.assertEqual(storage['retentionDaysOptions'], [1, 7, 30, 60, 90, 180, 365, 730, 1095, 1825, 3650, 0])

    def test_versioning_is_enabled_in_prepared_configuration(self):
        config = json.loads((ROOT / 'infrastructure/production/media-versioning.json').read_text())
        self.assertEqual(config, {'Status': 'Enabled'})
