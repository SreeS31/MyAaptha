import unittest
from sync_interest_catalog import TARGET,generated
class InterestCatalogueParityTest(unittest.TestCase):
 def test_native_catalogue_matches_web_source(self):
  self.assertEqual(TARGET.read_text(encoding='utf-8'),generated(),'Run python infrastructure/sync_interest_catalog.py')
