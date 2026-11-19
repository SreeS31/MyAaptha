import hashlib
import unittest
from update_beta_contacts import overlay_change


class ContactRolloutTest(unittest.TestCase):
    def test_overlay_changes_require_the_exact_previous_configuration(self):
        before = 'services:\n  backend: {}\n'
        candidate = 'GOOGLE_CONTACTS_CLIENT_SECRET: ${GOOGLE_CONTACTS_CLIENT_SECRET:-}\n'
        expected = hashlib.sha256(before.encode()).hexdigest()
        self.assertEqual(overlay_change(before, candidate, expected), candidate)
        with self.assertRaises(ValueError):
            overlay_change(before + '# unrelated change\n', candidate, expected)
        with self.assertRaises(ValueError):
            overlay_change(before, 'different configuration', expected)
