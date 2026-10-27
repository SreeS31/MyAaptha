"""Validate launch dependencies and rank unresolved prerequisites. No approvals inferred."""
import json
from pathlib import Path


def complete(task):
    values = list(task['stages'].values())
    return any(v != 'na' for v in values) and all(v in ('done', 'na') for v in values)


def analyze(data):
    tasks = [t for m in data['modules'] for t in m['tasks']]
    by_id = {t['id']: t for t in tasks}
    if len(by_id) != len(tasks):
        raise ValueError('Duplicate task ID')
    visited, active = set(), set()

    def visit(key):
        if key not in by_id:
            raise ValueError('Unknown dependency: ' + key)
        if key in active:
            raise ValueError('Dependency cycle: ' + key)
        if key in visited:
            return
        active.add(key)
        for dep in by_id[key]['depends']:
            visit(dep)
        active.remove(key)
        visited.add(key)

    for key in by_id:
        visit(key)
    pending = {key for key, t in by_id.items() if not complete(t)}

    def ancestors(key):
        result = set()
        for dep in by_id[key]['depends']:
            if dep in pending:
                result.add(dep)
                result.update(ancestors(dep))
        return result

    ancestry = {key: ancestors(key) for key in pending}
    audit = {i['id']: i for i in data['acceptanceAudit']['items']}
    if set(audit) != pending:
        raise ValueError('Acceptance requirements do not match pending tasks')
    rows = []
    for key in sorted(pending):
        descendants = sorted(k for k in pending if key in ancestry[k])
        rows.append(dict(id=key, title=by_id[key]['title'],
                         pendingPrerequisites=sorted(ancestry[key]),
                         downstreamTasks=descendants, downstreamCount=len(descendants),
                         required=audit[key]['required'], nextAction=audit[key]['nextAction']))
    rows.sort(key=lambda row: (-row['downstreamCount'], row['id']))
    return dict(snapshot=data['snapshot'], pending=len(pending),
                roots=[r['id'] for r in rows if not r['pendingPrerequisites']],
                tasks=rows, releaseApproved=False,
                interpretation='Downstream counts overlap. A root has no open checklist prerequisite; it can still require external access or review. Completing one prerequisite does not close its dependants.')


def write_report(data, output):
    report = analyze(data)
    output = Path(output)
    (output / 'dependency-priorities.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    lines = ['# Launch dependency priorities', '', report['interpretation'], '',
             f"{report['pending']} launch gates pending. Ranked by the number of other pending tasks that depend on each gate.", '',
             '| Gate | Downstream gates | Open prerequisites | Required input / next engineering action |',
             '|---|---:|---|---|']
    for row in report['tasks']:
        cells = [row['id'] + ' ' + row['title'], str(row['downstreamCount']),
                 ', '.join(row['pendingPrerequisites']) or 'No open checklist prerequisite',
                 row['required'] + ' Next: ' + row['nextAction']]
        lines.append('| ' + ' | '.join(c.replace('|', '\\|').replace('\n', ' ') for c in cells) + ' |')
    (output / 'DEPENDENCY-PRIORITIES.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return report
