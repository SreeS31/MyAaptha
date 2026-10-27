"""Offline review of synthetic help answers. Never calls a provider or enables AI."""
import argparse
import hashlib
import json
import math
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARTICLES = ROOT / 'backend/spring-boot-app/src/main/resources/help/articles.json'
CASES = ROOT / 'infrastructure/help-evaluation-cases.json'
RUBRIC = ('accuracy', 'privacy', 'grounding', 'actionHonesty')


def valid_cost(value):
    try:
        return type(value) in (int, float) and math.isfinite(value) and value >= 0
    except OverflowError:
        return False


def read_json(path):
    def reject_duplicates(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError('Duplicate JSON key: ' + key)
            result[key] = value
        return result
    return json.loads(Path(path).read_text(encoding='utf-8'),
                      object_pairs_hook=reject_duplicates,
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError('Non-finite JSON number')))


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False,
                                    separators=(',', ':')).encode('utf-8')).hexdigest()


def prepare(articles, cases):
    ids = {article['id'] for article in articles}
    if len(ids) != len(articles):
        raise ValueError('Duplicate article IDs')
    seen = set()
    for case in cases:
        if case['id'] in seen or not case['question'].strip() or not case['reviewFocus'].strip():
            raise ValueError('Invalid or duplicate evaluation case')
        seen.add(case['id'])
        if not set(case['expectedSources']).issubset(ids):
            raise ValueError('Case references unknown article')
    if not cases:
        raise ValueError('Evaluation cases are empty')
    return dict(schemaVersion=1, knowledgeSha256=fingerprint(articles),
                casesSha256=fingerprint(cases), cases=cases,
                rubric=list(RUBRIC), releaseApproved=False)


def compare(articles, cases, run):
    prepared = prepare(articles, cases)
    if not isinstance(run, dict) or run.get('schemaVersion') != 1:
        raise ValueError('Expected evaluation export schemaVersion 1')
    for field in ('knowledgeSha256', 'casesSha256'):
        if run.get(field) != prepared[field]:
            raise ValueError('Stale or missing ' + field)
    models = run.get('models')
    if not isinstance(models, list) or len(models) != 2 or any(not isinstance(m, str) or not m.strip() for m in models) or models[0] == models[1]:
        raise ValueError('Specify distinct base and candidate model identifiers')
    rows = run.get('responses')
    if not isinstance(rows, list):
        raise ValueError('responses must be an array')
    expected = {case['id']: case for case in cases}
    known_sources = {article['id'] for article in articles}
    indexed = {}
    for row in rows:
        if not isinstance(row, dict) or row.get('model') not in models or row.get('caseId') not in expected:
            raise ValueError('Unknown model or evaluation case')
        key = (row['model'], row['caseId'])
        if key in indexed:
            raise ValueError('Duplicate model/case response')
        indexed[key] = row
    summaries = []
    for model in models:
        results = []
        for case_id, case in expected.items():
            row = indexed.get((model, case_id))
            issues = []
            if row is None:
                issues.append('missing response')
            else:
                answer = row.get('answer')
                if not isinstance(answer, str) or not answer.strip() or len(answer) > 5000:
                    issues.append('invalid answer')
                sources = row.get('sourceIds')
                if (not isinstance(sources, list) or any(not isinstance(s, str) for s in sources)
                        or len(sources) != len(set(sources)) or not set(sources).issubset(known_sources)):
                    issues.append('invalid citations')
                elif set(sources) != set(case['expectedSources']):
                    issues.append('citations differ from reviewed case expectations')
                for field in ('inputTokens', 'outputTokens', 'latencyMs'):
                    value = row.get(field)
                    if type(value) is not int or value < 0:
                        issues.append('invalid ' + field)
                cost = row.get('costUsd')
                if cost is not None and not valid_cost(cost):
                    issues.append('invalid costUsd')
                review = row.get('review')
                if not isinstance(review, dict) or any(not isinstance(review.get(f), str) or not review[f].strip() for f in ('reviewer', 'reviewedAt', 'notes')):
                    issues.append('human review missing')
                else:
                    try:
                        timestamp = datetime.fromisoformat(review['reviewedAt'].replace('Z', '+00:00'))
                        if timestamp.tzinfo is None:
                            raise ValueError('Timezone required')
                    except ValueError:
                        issues.append('invalid review timestamp; use ISO 8601 with timezone')
                    scores = review.get('scores')
                    if not isinstance(scores, dict) or set(scores) != set(RUBRIC) or any(type(v) is not int or v not in (0, 1, 2) for v in scores.values()):
                        issues.append('invalid rubric scores')
                    elif any(value != 2 for value in scores.values()):
                        issues.append('review did not pass every rubric criterion')
            results.append(dict(caseId=case_id, passed=not issues, issues=issues))
        accepted = [indexed[(model, c)] for c in expected if (model, c) in indexed]
        costs = [r.get('costUsd') for r in accepted]
        total_cost = sum(costs) if len(costs) == len(cases) and all(valid_cost(v) for v in costs) else None
        if total_cost is not None and not valid_cost(total_cost):
            total_cost = None
        metrics = {}
        for field in ('inputTokens', 'outputTokens', 'latencyMs'):
            values = [r.get(field) for r in accepted]
            complete = len(values) == len(cases) and all(type(v) is int and v >= 0 for v in values)
            metrics[field + 'Total'] = sum(values) if complete else None
        latencies = sorted(r['latencyMs'] for r in accepted) if metrics['latencyMsTotal'] is not None else []
        metrics['latencyMsP95'] = latencies[math.ceil(len(latencies) * .95) - 1] if latencies else None
        summaries.append(dict(model=model, passed=sum(r['passed'] for r in results), total=len(results),
                              reportedCostUsd=total_cost, metrics=metrics, results=results))
    return dict(schemaVersion=1, knowledgeSha256=prepared['knowledgeSha256'],
                casesSha256=prepared['casesSha256'], models=summaries,
                comparisonComplete=all(m['passed'] == m['total'] for m in summaries),
                releaseApproved=False,
                notice='Imported scores are reviewer assertions, not independently verified model quality or release approval. Costs are supplied values, not provider billing verification.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--responses', type=Path, help='Compare a reviewed export; omit to prepare cases')
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    try:
        # Do not overwrite inputs, including a caller-supplied response export.
        protected = [ARTICLES, CASES] + ([args.responses] if args.responses else [])
        if args.output.resolve() in [p.resolve() for p in protected]:
            raise ValueError('Output must differ from input files')
        articles, cases = read_json(ARTICLES), read_json(CASES)
        result = compare(articles, cases, read_json(args.responses)) if args.responses else prepare(articles, cases)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False) + '\n', encoding='utf-8')
        print(json.dumps(dict(prepared=not bool(args.responses), comparisonComplete=result.get('comparisonComplete', False), releaseApproved=False)))
        return 0 if not args.responses or result['comparisonComplete'] else 1
    except (OSError, ValueError, KeyError, TypeError) as exc:
        parser.exit(2, str(exc) + '\n')


if __name__ == '__main__':
    raise SystemExit(main())
