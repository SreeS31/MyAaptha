import unittest
from sync_display_copy import outputs


class DisplayCopyParityTest(unittest.TestCase):
    def test_web_and_native_match_api_resource(self):
        for path, expected in outputs().items():
            with self.subTest(client=path.name):
                self.assertEqual(path.read_text(encoding='utf-8'), expected,
                                 'Run python infrastructure/sync_display_copy.py')
