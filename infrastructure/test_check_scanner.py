from datetime import datetime,timezone
import unittest
from check_scanner import signature_is_fresh

class ScannerFreshnessTest(unittest.TestCase):
    now=datetime(2026,10,17,12,tzinfo=timezone.utc)
    def test_recent_and_whitespace_padded_date(self):
        self.assertTrue(signature_is_fresh('ClamAV 1.5.4/28156/Sat Oct 17 06:24:12 2026',self.now))
        self.assertTrue(signature_is_fresh('ClamAV 1.5.4/28156/Sat Oct  17 06:24:12 2026',self.now))
    def test_old_or_future_signatures_are_rejected(self):
        self.assertFalse(signature_is_fresh('ClamAV 1.5.4/28147/Thu Oct 8 06:24:12 2026',self.now))
        self.assertFalse(signature_is_fresh('ClamAV 1.5.4/28156/Sat Oct 17 14:00:00 2026',self.now))
    def test_exact_48_hour_and_one_hour_future_boundaries(self):
        self.assertTrue(signature_is_fresh('ClamAV 1.5.4/28156/Thu Oct 15 12:00:00 2026',self.now))
        self.assertTrue(signature_is_fresh('ClamAV 1.5.4/28156/Sat Oct 17 13:00:00 2026',self.now))
    def test_invalid_version_never_passes(self):
        for version in ['no date','ClamAV/x/not-a-date']:
            with self.assertRaises(ValueError):signature_is_fresh(version,self.now)

if __name__=='__main__':unittest.main()
