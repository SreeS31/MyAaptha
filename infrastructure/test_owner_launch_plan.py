import copy
import json
from pathlib import Path
import unittest
import yaml
from owner_launch_plan import estimate,inspect,ROOT

class OwnerPlanTests(unittest.TestCase):
 def setUp(self):self.profile=json.loads((ROOT/'docs/launch-board/owner-launch-inputs-2026-10-26.json').read_text(encoding='utf-8'))
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
