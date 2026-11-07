import copy
import hashlib
import tempfile
from contextlib import contextmanager
import json
from pathlib import Path
import unittest
import yaml
from owner_launch_plan import estimate,inspect,ROOT

class OwnerPlanTests(unittest.TestCase):
 def setUp(self):self.profile=json.loads((ROOT/'docs/launch-board/owner-launch-inputs-2026-10-26.json').read_text(encoding='utf-8'))
 @contextmanager
 def snapshot_fixture(self,canonical=True):
  with tempfile.TemporaryDirectory(prefix='myaaptha-owner-snapshot-') as folder:
   root=Path(folder).resolve()
   self.assertTrue(root.is_relative_to(Path(tempfile.gettempdir()).resolve()))
   source=root/'owner.txt';content=b'Owner: fixture\r\nBudget: 6000\r\n';source.write_bytes(content)
   profile=copy.deepcopy(self.profile);profile['sourceFile']='owner.txt'
   profile['sourceSha256']=hashlib.sha256(content).hexdigest()
   profile.pop('sourceCanonicalSha256',None)
   if canonical:profile['sourceCanonicalSha256']=hashlib.sha256(content.replace(b'\r\n',b'\n')).hexdigest()
   path=root/'profile.json';path.write_text(json.dumps(profile),encoding='utf-8')
   yield root,path,source,content
 def test_snapshot_matches_lf_and_crlf_without_granting_acceptance(self):
  with self.snapshot_fixture() as (root,path,source,content):
   for payload in (content,content.replace(b'\r\n',b'\n')):
    source.write_bytes(payload);report=inspect(path,root)
    self.assertTrue(report['ownerInputSnapshotCurrent'])
    self.assertEqual('sha256-lf-v1',report['ownerInputSnapshotHashMode'])
    self.assertFalse(report['releaseApproved']);self.assertFalse(report['externalServicesContacted'])
 def test_snapshot_rejects_content_whitespace_bom_and_missing_source_changes(self):
  with self.snapshot_fixture() as (root,path,source,content):
   for payload in (content.replace(b'6000',b'6100'),content.replace(b'fixture',b'fixture '),b'\xef\xbb\xbf'+content,content.replace(b'\r\n',b'\r')):
    source.write_bytes(payload);self.assertFalse(inspect(path,root)['ownerInputSnapshotCurrent'])
   source.unlink();self.assertFalse(inspect(path,root)['ownerInputSnapshotCurrent'])
 def test_legacy_snapshot_remains_byte_exact(self):
  with self.snapshot_fixture(canonical=False) as (root,path,source,content):
   report=inspect(path,root);self.assertTrue(report['ownerInputSnapshotCurrent'])
   self.assertEqual('sha256-raw-v1',report['ownerInputSnapshotHashMode'])
   source.write_bytes(content.replace(b'\r\n',b'\n'))
   self.assertFalse(inspect(path,root)['ownerInputSnapshotCurrent'])
 def test_budget_uses_physical_storage_and_separate_ai_budget(self):
  result=estimate(self.profile)
  self.assertEqual(5773.15,result['inr']);self.assertTrue(result['withinBudget'])
  self.assertFalse(result['capacityAccepted'])
 def test_full_quota_is_not_claimed_affordable(self):
  result=estimate(self.profile,1000,1000)
  self.assertFalse(result['withinBudget']);self.assertEqual(10817.65,result['inr'])
 def test_invalid_budget_numbers_fail(self):
  for value in [-1,'NaN','Infinity']:
   p=copy.deepcopy(self.profile);p['proposed']['activeMediaGb']=value
   with self.assertRaises(ValueError):estimate(p)
 def test_input_snapshot_is_not_external_acceptance(self):
  report=inspect(ROOT/'docs/launch-board/owner-launch-inputs-2026-10-26.json')
  self.assertTrue(report['ownerInputSnapshotCurrent'])
  self.assertFalse(report['releaseApproved']);self.assertFalse(report['externalServicesContacted'])
  self.assertTrue(all(not x['liveValidated'] for x in report['protectedConfigurationPresence'].values()))
 def test_budget_profile_keeps_database_and_cache_private_and_encrypted(self):
  data=yaml.safe_load((ROOT/'infrastructure/production/compose.single-host.yml').read_text())
  for key in ['postgres','redis']:self.assertNotIn('ports',data['services'][key])
  env=data['services']['backend']['environment']
  self.assertEqual('verify-full',env['POSTGRES_SSLMODE']);self.assertEqual('true',env['REDIS_TLS'])
  self.assertEqual('internal',env['SPRING_DATA_REDIS_SSL_BUNDLE'])
 def test_integration_mount_is_readonly_and_health_is_not_silently_enabled(self):
  data=yaml.safe_load((ROOT/'infrastructure/production/compose.integrations.yml').read_text())['services']['backend']
  self.assertIn('./secrets/integrations:/run/integrations:ro',data['volumes'])
  self.assertIn('false',data['environment']['MYAAPTHA_HEALTH_AI_ENABLED'])
  self.assertIn('configtree:/run/secrets/',data['environment']['SPRING_CONFIG_IMPORT'])

if __name__=='__main__':unittest.main()
