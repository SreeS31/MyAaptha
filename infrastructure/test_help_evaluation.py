import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from help_evaluation import ARTICLES, CASES, RUBRIC, compare, prepare, read_json


class HelpEvaluationTests(unittest.TestCase):
    def setUp(self):
        self.articles = read_json(ARTICLES)
        self.cases = read_json(CASES)
        prepared = prepare(self.articles, self.cases)
        self.run = dict(schemaVersion=1, knowledgeSha256=prepared['knowledgeSha256'],
                        casesSha256=prepared['casesSha256'], models=['fixture-base', 'fixture-candidate'], responses=[])
        for model in self.run['models']:
            for case in self.cases:
                self.run['responses'].append(dict(model=model, caseId=case['id'], answer='Synthetic fixture only.',
                    sourceIds=case['expectedSources'], inputTokens=100, outputTokens=20, latencyMs=50,
                    review=dict(reviewer='fixture reviewer', reviewedAt='2026-10-18T00:00:00Z',
                                notes='Synthetic test, not an actual quality evaluation.', scores={k: 2 for k in RUBRIC})))

    def result(self):
        return compare(self.articles, self.cases, self.run)

    def test_complete_review_never_approves_release_or_invents_costs(self):
        result = self.result()
        self.assertTrue(result['comparisonComplete'])
        self.assertFalse(result['releaseApproved'])
        self.assertEqual(10, result['models'][0]['passed'])
        self.assertIsNone(result['models'][0]['reportedCostUsd'])
        self.assertEqual(1000, result['models'][0]['metrics']['inputTokensTotal'])
        self.assertEqual(50, result['models'][0]['metrics']['latencyMsP95'])
        self.assertNotIn('answer', json.dumps(result))

    def test_missing_case_or_human_review_fails_closed(self):
        self.run['responses'].pop()
        self.run['responses'][0].pop('review')
        result = self.result()
        self.assertFalse(result['comparisonComplete'])
        self.assertEqual([9, 9], [m['passed'] for m in result['models']])

    def test_privacy_failure_and_boolean_scores_are_not_passing(self):
        self.run['responses'][0]['review']['scores']['privacy'] = 0
        self.run['responses'][1]['review']['scores']['accuracy'] = True
        self.assertEqual(8, self.result()['models'][0]['passed'])

    def test_review_time_requires_timezone_and_cost_requires_complete_coverage(self):
        self.run['responses'][0]['review']['reviewedAt'] = 'yesterday'
        self.assertFalse(self.result()['comparisonComplete'])
        self.run['responses'][0]['review']['reviewedAt'] = '2026-10-18T12:00:00'
        self.assertFalse(self.result()['comparisonComplete'])
        self.run['responses'][0]['review']['reviewedAt'] = '2026-10-18T12:00:00+05:30'
        for row in self.run['responses']:
            row['costUsd'] = .01
        self.assertAlmostEqual(.1, self.result()['models'][0]['reportedCostUsd'])

    def test_citations_usage_and_cost_are_checked(self):
        for field, value in [('sourceIds', ['made-up']), ('sourceIds', ['pricing', 'pricing']),
                             ('sourceIds', [{}]), ('inputTokens', True), ('latencyMs', -1),
                             ('costUsd', float('nan')), ('answer', '')]:
            with self.subTest(field=field, value=value):
                run = copy.deepcopy(self.run)
                run['responses'][0][field] = value
                self.assertFalse(compare(self.articles, self.cases, run)['comparisonComplete'])
        self.run['responses'][0]['sourceIds'] = []
        self.assertFalse(self.result()['comparisonComplete'])

    def test_export_drift_unknown_rows_and_duplicates_rejected(self):
        for mutate in [lambda r: r.update(knowledgeSha256='stale'),
                       lambda r: r.update(casesSha256='stale'),
                       lambda r: r.update(models=['same', 'same']),
                       lambda r: r['responses'].append(r['responses'][0]),
                       lambda r: r['responses'][0].update(caseId='unknown')]:
            run = copy.deepcopy(self.run)
            mutate(run)
            with self.assertRaises(ValueError):
                compare(self.articles, self.cases, run)
        revised = copy.deepcopy(self.articles)
        revised[0]['content'] += ' Changed.'
        with self.assertRaises(ValueError):
            compare(revised, self.cases, self.run)

    def test_cli_prepares_without_provider_and_returns_nonzero_for_incomplete_review(self):
        script = Path(__file__).with_name('help_evaluation.py')
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'prepared.json'
            prepared = subprocess.run([sys.executable, str(script), '--output', str(output)], capture_output=True, text=True)
            self.assertEqual(0, prepared.returncode, prepared.stderr)
            self.assertEqual(10, len(read_json(output)['cases']))
            run_file = Path(directory) / 'responses.json'
            self.run['responses'].pop()
            run_file.write_text(json.dumps(self.run), encoding='utf-8')
            review = subprocess.run([sys.executable, str(script), '--responses', str(run_file), '--output', str(output)], capture_output=True, text=True)
            self.assertEqual(1, review.returncode, review.stderr)
            self.assertFalse(read_json(output)['comparisonComplete'])
            rejected = subprocess.run([sys.executable, str(script), '--responses', str(run_file), '--output', str(run_file)], capture_output=True, text=True)
            self.assertEqual(2, rejected.returncode)
            self.assertEqual(self.run, read_json(run_file))

    def test_duplicate_json_keys_and_nonfinite_numbers_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'bad.json'
            for payload in ['{"a":1,"a":2}', '{"costUsd":NaN}']:
                path.write_text(payload, encoding='utf-8')
                with self.assertRaises(ValueError):
                    read_json(path)


if __name__ == '__main__':
    unittest.main()
