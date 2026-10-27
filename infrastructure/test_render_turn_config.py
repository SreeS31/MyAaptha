from pathlib import Path
import unittest
from render_turn_config import render,ROOT

class TurnConfigTests(unittest.TestCase):
 def test_render_preserves_auth_tls_and_private_peer_denials(self):
  text=render((ROOT/'turnserver.conf.example').read_text(),'test-only-signing-secret-1234567890','8.8.8.8','10.0.0.8')
  self.assertIn('use-auth-secret',text);self.assertIn('external-ip=8.8.8.8/10.0.0.8',text)
  self.assertIn('denied-peer-ip=169.254.0.0-169.254.255.255',text)
  self.assertNotIn('REPLACE_',text);self.assertIn('total-quota=40',text)
 def test_invalid_addresses_and_injected_secret_are_rejected(self):
  for public,private,secret in [('127.0.0.1','10.0.0.8','x'*40),('169.254.169.254','10.0.0.8','x'*40),('8.8.8.8','127.0.0.1','x'*40),('8.8.8.8','10.0.0.8','x'*40+'\nno-auth')]:
   with self.assertRaises(ValueError):render('REPLACE_WITH_PROTECTED_SHARED_SECRET',secret,public,private)

if __name__=='__main__':unittest.main()
