import tempfile
import unittest
from pathlib import Path
import yaml
from render_release import ROOT, render, validate
import json

class ReleaseValidationTest(unittest.TestCase):
    def valid(self):
        config = json.loads((ROOT / 'release.example.json').read_text())
        config.update(trusted_proxy_regex='10[.]0[.]1[.][0-9]{1,3}', redis_host='cache.myaaptha.internal', domain='app.myaaptha.test', postgres_host='db.myaaptha.internal', storage_bucket='myaaptha-private')
        for key in ('backend_image', 'frontend_image', 'ai_image'):
            config[key] = 'ghcr.io/myaaptha/' + key + '@sha256:' + 'a' * 64
        return config
    def test_connection_budget_includes_rollout_surge(self):
        config=self.valid();config['db_connection_budget']=259
        with self.assertRaisesRegex(ValueError,'connection budget'):validate(config)
        config['db_connection_budget']=260;validate(config)
    def test_dummy_configuration_is_rejected(self):
        with self.assertRaises(ValueError): validate(json.loads((ROOT / 'release.example.json').read_text()))
    def test_mutable_tag_is_rejected(self):
        config = self.valid(); config['backend_image'] = 'ghcr.io/myaaptha/backend:latest'
        with self.assertRaises(ValueError): validate(config)
    def test_render_routes_and_images_match_release(self):
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder); render(self.valid(), destination)
            ingress = yaml.safe_load((destination / 'ingress.yaml').read_text())
            self.assertEqual('app.myaaptha.test', ingress['spec']['rules'][0]['host'])
            for obj in yaml.safe_load_all((destination / 'app.yaml').read_text()):
                if obj['kind'] == 'Deployment':
                    self.assertIn('@sha256:', obj['spec']['template']['spec']['containers'][0]['image'])
            config = yaml.safe_load((destination / 'config.yaml').read_text())
            self.assertEqual('false', config['data']['SPRING_FLYWAY_ENABLED'])
            self.assertEqual('https://app.myaaptha.test', config['data']['MYAAPTHA_WEB_ORIGIN'])

    def test_every_database_workload_receives_the_provider_ca(self):
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder); render(self.valid(), destination)
            workloads = []
            for filename in ('app.yaml', 'migration-job.yaml', 'encrypt-fields-job.yaml'):
                for obj in yaml.safe_load_all((destination / filename).read_text()):
                    if obj['kind'] == 'Job' or (obj['kind'] == 'Deployment' and obj['metadata']['name'] == 'backend'):
                        workloads.append(obj)
            self.assertEqual(3, len(workloads))
            for obj in workloads:
                spec = obj['spec']['template']['spec']
                self.assertIn({'name': 'postgres-ca', 'configMap': {'name': 'myaaptha-postgres-ca'}}, spec['volumes'])
                self.assertIn({'name': 'postgres-ca', 'mountPath': '/home/myaaptha/.postgresql', 'readOnly': True},
                              spec['containers'][0]['volumeMounts'])
                self.assertEqual(self.valid()['backend_image'], spec['containers'][0]['image'])

    def test_compose_cannot_start_backend_before_encryption_finishes(self):
        services = yaml.safe_load((ROOT / 'production/docker-compose.prod.yml').read_text())['services']
        self.assertNotIn('profiles', services['encrypt-fields'])
        for dependent, prerequisite in [('backend', 'encrypt-fields'), ('encrypt-fields', 'migrate')]:
            self.assertEqual('service_completed_successfully', services[dependent]['depends_on'][prerequisite]['condition'])
        for name in ('backend', 'migrate', 'encrypt-fields'):
            self.assertIn('./certs/postgres-ca.crt:/home/myaaptha/.postgresql/root.crt:ro', services[name]['volumes'])

    def test_optional_scrape_credential_is_scoped_to_backend_only(self):
        services=yaml.safe_load((ROOT/'production/docker-compose.prod.yml').read_text())['services']
        key='MYAAPTHA_METRICS_SCRAPE_TOKEN'
        self.assertEqual('${MYAAPTHA_METRICS_SCRAPE_TOKEN:-}',services['backend']['environment'][key])
        for name,service in services.items():
            if name!='backend': self.assertNotIn(key,service.get('environment',{}),name)

if __name__ == '__main__': unittest.main()
