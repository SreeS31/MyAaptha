import unittest
import ipaddress
from pathlib import Path
import yaml
from prepare_gcp_beta import validate


class BetaInputSafetyTest(unittest.TestCase):
    def test_static_service_addresses_cannot_be_allocated_to_dependencies(self):
        config = yaml.safe_load((Path(__file__).parent / 'production/compose.gcp-beta.yml').read_text())
        pools = config['networks']['default']['ipam']['config']
        addresses = [ipaddress.ip_address(network['ipv4_address'])
                     for service in config['services'].values()
                     for network in service.get('networks', {}).values()
                     if 'ipv4_address' in network]
        self.assertEqual(len(addresses), len(set(addresses)))
        for pool in pools:
            subnet = ipaddress.ip_network(pool['subnet'])
            dynamic = ipaddress.ip_network(pool.get('ip_range', pool['subnet']))
            self.assertTrue(dynamic.subnet_of(subnet))
            for address in addresses:
                self.assertIn(address, subnet)
                self.assertNotIn(address, dynamic, 'Dynamic allocation can steal a reserved service address')

    def images(self):
        return {name: 'registry.test/app@sha256:' + 'a' * 64
                for name in ('backend', 'frontend', 'ai', 'postgres', 'redis', 'gateway', 'clamav')}

    def test_accepts_only_digest_pinned_images(self):
        validate(self.images(), 'beta.myaaptha.com', 'private-beta-media', 'myaaptha-beta-project')
        images = self.images()
        images['backend'] = 'registry.test/app:latest'
        with self.assertRaises(ValueError):
            validate(images, 'beta.myaaptha.com', 'private-beta-media', 'myaaptha-beta-project')

    def test_rejects_missing_images_and_environment_injection(self):
        images = self.images()
        del images['clamav']
        with self.assertRaises(ValueError):
            validate(images, 'beta.myaaptha.com', 'private-beta-media', 'myaaptha-beta-project')
        for domain in ['https://beta.myaaptha.com', 'beta.myaaptha.com\nKEY=value', '$(command).com']:
            with self.assertRaises(ValueError):
                validate(self.images(), domain, 'private-beta-media', 'myaaptha-beta-project')

    def test_rejects_bucket_and_project_injection(self):
        for bucket, project in [('private-beta-media\nKEY=value', 'myaaptha-beta-project'),
                                ('private-beta-media', 'project\nKEY=value')]:
            with self.assertRaises(ValueError):
                validate(self.images(), 'beta.myaaptha.com', bucket, project)


if __name__ == '__main__':
    unittest.main()
