import unittest
from configure_beta_call_relay import configuration

class BetaCallRelayTest(unittest.TestCase):
    def test_relay_requires_auth_and_denies_private_peers(self):
        value=configuration('a'*48,'35.244.31.192','10.10.0.2')
        self.assertIn('use-auth-secret\n',value)
        self.assertIn('external-ip=35.244.31.192/10.10.0.2',value)
        self.assertIn('denied-peer-ip=169.254.0.0-169.254.255.255',value)
        self.assertIn('no-cli\n',value)
        self.assertNotIn('no-auth\n',value)
    def test_secrets_cannot_inject_coturn_directives(self):
        with self.assertRaises(ValueError):configuration('a'*48+'\nno-auth','35.244.31.192','10.10.0.2')
    def test_only_public_to_private_ipv4_mapping_is_accepted(self):
        for public,private in [('127.0.0.1','10.10.0.2'),('35.244.31.192','127.0.0.1'),('35.244.31.192','169.254.1.1')]:
            with self.assertRaises(ValueError):configuration('a'*48,public,private)

if __name__=='__main__':unittest.main()
