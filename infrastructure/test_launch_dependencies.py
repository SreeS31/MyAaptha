import unittest
from launch_dependencies import analyze


def board(edges, done=()):
    tasks = [dict(id=k, title=k, depends=v, stages=dict(coding='done' if k in done else 'pending')) for k, v in edges.items()]
    return dict(snapshot='test', modules=[dict(tasks=tasks)], acceptanceAudit=dict(items=[dict(id=k, required='Access', nextAction='Verify') for k in edges if k not in done]))


class DependencyTests(unittest.TestCase):
    def test_transitive_diamond_counts_unique_tasks(self):
        result = analyze(board({'A': [], 'B': ['A'], 'C': ['A'], 'D': ['B', 'C']}))
        self.assertEqual(result['tasks'][0]['downstreamCount'], 3)
        self.assertEqual(result['roots'], ['A'])
        self.assertFalse(result['releaseApproved'])

    def test_completed_prerequisite_does_not_close_dependant(self):
        result = analyze(board({'A': [], 'B': ['A']}, done=['A']))
        self.assertEqual(result['pending'], 1)
        self.assertEqual(result['roots'], ['B'])

    def test_bad_graph_or_missing_acceptance_rejected(self):
        for edges in ({'A': ['B']}, {'A': ['B'], 'B': ['A']}):
            with self.assertRaises(ValueError):
                analyze(board(edges))
        data = board({'A': []})
        data['acceptanceAudit']['items'] = []
        with self.assertRaises(ValueError):
            analyze(data)
