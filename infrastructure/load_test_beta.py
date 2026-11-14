"""Bounded read-only beta load test. No logins, account writes or uploaded files.

Run from the client whose network latency you want to measure. Results include
client/network overhead and are not a maximum-capacity benchmark.
"""
import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import datetime
import http.client
import json
from pathlib import Path
import ssl
import threading
import time
from urllib.parse import urlparse

PATHS = ['/', '/auth', '/', '/recover-account', '/api/auth/security-policy', '/actuator/health']
PHASES = [('baseline', 1, 1, 20), ('moderate', 5, 3, 30), ('peak', 10, 5, 45), ('recovery', 1, 1, 20)]


def percentile(values, percent):
    ordered = sorted(values)
    return round(ordered[max(0, (len(ordered) * percent + 99) // 100 - 1)], 1) if ordered else None


def summarize(records):
    values = [r['ms'] for r in records]
    failures = sum(not r['ok'] for r in records)
    return {'requests': len(records), 'failures': failures,
            'errorPercent': round(failures * 100 / len(records), 2) if records else 0,
            'statuses': dict(Counter(str(r['status']) for r in records)),
            'p50Ms': percentile(values, 50), 'p95Ms': percentile(values, 95),
            'p99Ms': percentile(values, 99), 'maxMs': round(max(values), 1) if values else None}


def run(base_url, output):
    parsed = urlparse(base_url)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.path not in ('', '/') or parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise ValueError('Supply an HTTPS origin without credentials, paths or query strings')
    context = ssl.create_default_context()
    local = threading.local()
    connections = []
    connection_lock = threading.Lock()

    def fetch(path):
        start = time.monotonic()
        status = 'network-error'
        try:
            if not getattr(local, 'connection', None):
                local.connection = http.client.HTTPSConnection(parsed.hostname, parsed.port or 443, timeout=8, context=context)
                with connection_lock:
                    connections.append(local.connection)
            connection = local.connection
            connection.request('GET', path, headers={'User-Agent': 'MyAaptha-bounded-beta-check/1.0', 'Accept': 'application/json,text/html'})
            response = connection.getresponse()
            status = response.status
            data = response.read(8 * 1024 * 1024)
            ok = status == 200
            if path == '/actuator/health' and ok:
                ok = json.loads(data).get('status') == 'UP'
            elif path.startswith('/api/') and ok:
                ok = isinstance(json.loads(data), dict)
            elif ok:
                ok = b'<html' in data.lower()
            return {'path': path, 'status': status, 'ok': ok, 'ms': round((time.monotonic() - start) * 1000, 1), 'bytes': len(data)}
        except (OSError, http.client.HTTPException, ValueError):
            if getattr(local, 'connection', None):
                local.connection.close()
                local.connection = None
            return {'path': path, 'status': status, 'ok': False, 'ms': round((time.monotonic() - start) * 1000, 1), 'bytes': 0}

    report = {'target': base_url.rstrip('/'), 'startedUtc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'scope': 'Public read-only endpoints; persistent HTTPS connections; no authenticated business transactions',
              'provisionalThresholds': {'errorPercentBelow': 1, 'p95MsBelow': 1500}, 'phases': [], 'aborted': False}
    all_records = []
    try:
        for name, concurrency, rate, duration in PHASES:
            records, pending, skipped = [], set(), 0
            start = time.monotonic()
            with ThreadPoolExecutor(max_workers=concurrency) as pool:
                for i in range(rate * duration):
                    time.sleep(max(0, start + i / rate - time.monotonic()))
                    finished = {future for future in pending if future.done()}
                    records.extend(f.result() for f in finished)
                    pending -= finished
                    recent = records[-20:]
                    if len(recent) == 20 and (sum(not r['ok'] for r in recent) >= 3 or percentile([r['ms'] for r in recent], 95) > 3000):
                        report['aborted'] = True
                        break
                    if len(pending) < concurrency:
                        pending.add(pool.submit(fetch, PATHS[i % len(PATHS)]))
                    else:
                        skipped += 1
                records.extend(f.result() for f in pending)
            elapsed = time.monotonic() - start
            recent = records[-20:]
            if len(recent) == 20 and (sum(not r['ok'] for r in recent) >= 3 or percentile([r['ms'] for r in recent], 95) > 3000):
                report['aborted'] = True
            phase = {'name': name, 'maxConcurrentRequests': concurrency, 'targetRps': rate,
                     'plannedSeconds': duration, 'elapsedSeconds': round(elapsed, 2), 'skippedRequests': skipped,
                     'achievedRps': round(len(records) / elapsed, 2), **summarize(records)}
            report['phases'].append(phase)
            all_records.extend(records)
            print(json.dumps(phase), flush=True)
            if report['aborted']:
                break
    finally:
        for connection in connections:
            connection.close()
        report['summary'] = summarize(all_records)
        report['endpoints'] = {path: summarize([r for r in all_records if r['path'] == path]) for path in PATHS}
        report['requests'] = all_records
        report['finishedUtc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        report['passedProvisionalThresholds'] = not report['aborted'] and report['summary']['requests'] > 0 and report['summary']['errorPercent'] < 1 and report['summary']['p95Ms'] < 1500 and not any(p['skippedRequests'] for p in report['phases'])
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({'summary': report['summary'], 'passedProvisionalThresholds': report['passedProvisionalThresholds'], 'aborted': report['aborted']}), flush=True)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-url', default='https://35-244-31-192.sslip.io')
    parser.add_argument('--output', type=Path, default=Path('.tools/beta-load-20261114.json'))
    args = parser.parse_args()
    result = run(args.base_url, args.output)
    raise SystemExit(0 if result['passedProvisionalThresholds'] else 1)
