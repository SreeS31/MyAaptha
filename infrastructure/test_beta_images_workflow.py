from pathlib import Path
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]


class BetaImagesWorkflowTests(unittest.TestCase):
    def test_beta_publication_is_separate_and_requires_ci_and_scans(self):
        workflow = yaml.load((ROOT / '.github/workflows/beta-images.yml').read_text(encoding='utf-8'), Loader=yaml.BaseLoader)
        self.assertEqual(workflow['on'], {'push': {'tags': ['beta-*']}})
        self.assertEqual(workflow['jobs']['validate']['uses'], './.github/workflows/ci.yml')
        images = workflow['jobs']['images']
        self.assertEqual(images['needs'], 'validate')
        self.assertEqual({i['name'] for i in images['strategy']['matrix']['include']}, {'backend', 'frontend', 'ai-agent', 'postgres', 'gateway'})
        steps = images['steps']
        postgres = next(s for s in steps if s.get('name') == 'Verify patched PostgreSQL runtime')
        self.assertEqual(postgres['if'], "matrix.name == 'postgres'")
        self.assertIn('smoke_postgres_image.py', postgres['run'])
        scan = next(i for i, s in enumerate(steps) if s.get('name') == 'Block vulnerable images')
        publish = next(i for i, s in enumerate(steps) if s.get('name') == 'Publish scanned beta image')
        self.assertLess(scan, publish)
        self.assertEqual(steps[scan]['with']['severity'], 'CRITICAL,HIGH')
        self.assertEqual(steps[scan]['with']['exit-code'], '1')
        self.assertIn(':beta-${{ github.sha }}', steps[publish]['env']['IMAGE'])
        text = str(workflow)
        self.assertNotIn('gcloud ', text)
        self.assertNotIn('latest', steps[publish]['env']['IMAGE'])
