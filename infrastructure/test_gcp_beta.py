import tempfile
from pathlib import Path
import shlex
import unittest
from gcp_beta import plan, render


class GcpBetaTests(unittest.TestCase):
    def test_no_public_database_cache_storage_or_ssh(self):
        data = plan('myaaptha-beta-fixture')
        rules = [c for c in data['commands'] if 'firewall-rules' in c]
        self.assertEqual(len(rules), 3)
        for rule in rules:
            allow = next(a for a in rule if a.startswith('--allow='))
            if allow == '--allow=tcp:22':
                self.assertIn('--source-ranges=35.235.240.0/20', rule)
            else:
                self.assertNotIn('22', allow)
            for port in ('5432', '6379', '9000', '9001', '3310', '8080', '3000'):
                self.assertNotIn(port, allow)

    def test_no_default_cloud_identity_and_non_destructive_stop(self):
        data = plan('myaaptha-beta-fixture')
        vm = data['commands'][-1]
        for flag in ('--no-service-account', '--no-scopes', '--no-boot-disk-auto-delete',
                     '--max-run-duration=7d', '--instance-termination-action=STOP', '--shielded-secure-boot'):
            self.assertIn(flag, vm)
        self.assertIn('--tunnel-through-iap', data['accessCommand'])
        self.assertFalse(data['deployed'])
        self.assertFalse(data['cloudContacted'])
        self.assertFalse(data['releaseApproved'])

    def test_rejects_injection_placeholders_production_and_unreviewed_region(self):
        for project in ('myaaptha-prod', 'myaaptha-beta-example', 'beta;echo secret', '-beta-project', 'beta\nproject'):
            with self.assertRaises(ValueError):
                plan(project)
        with self.assertRaises(ValueError):
            plan('myaaptha-beta-fixture', 'us-central1-a')

    def test_project_scoped_commands_and_rendering(self):
        data = plan('myaaptha-beta-fixture')
        for command in data['commands']:
            self.assertIn('--project=myaaptha-beta-fixture', command)
            self.assertNotIn('delete', command)
        with tempfile.TemporaryDirectory() as folder:
            render(data, Path(folder))
            script = (Path(folder) / 'provision.sh').read_text(encoding='utf-8')
            lines = [shlex.split(line) for line in script.splitlines() if line.startswith('gcloud ')]
            self.assertEqual(lines, data['commands'])
            self.assertNotIn('gcloud auth', script)
            self.assertLess(script.index('MYAAPTHA_BETA_TRIAL_VERIFIED'), script.index('gcloud projects'))
