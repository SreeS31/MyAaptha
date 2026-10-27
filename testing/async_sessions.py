"""Memory-efficient distinct-user HTTP workload, matching concurrent-sessions.js.
Uses one asynchronous task per user; never reuses an account across tasks.
"""
import asyncio
from array import array
from collections import Counter, defaultdict
import json
import math
import os
from pathlib import Path
import sys
import time
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / '.tools/capacity-python'))
import aiohttp


def percentiles(samples):
    if not samples:
        return {'count': 0, 'p95_ms': None, 'max_ms': None}
    ordered = sorted(samples)
    return {'count': len(ordered), 'p95_ms': round(ordered[max(0, math.ceil(len(ordered)*.95)-1)], 2),
            'max_ms': round(ordered[-1], 2), 'mean_ms': round(sum(ordered)/len(ordered), 2)}


async def run():
    accounts = json.loads(Path(os.environ['ACCOUNTS_FILE']).read_text(encoding='utf-8'))
    vus = int(os.environ['VUS']); ramp = int(os.environ['RAMP_SECONDS']); hold = int(os.environ['HOLD_SECONDS'])
    origins = os.environ['ORIGINS'].split(',')
    if len(accounts) < vus or len({a['id'] for a in accounts}) != len(accounts):
        raise ValueError('Distinct fixture accounts are required')
    for a in accounts:
        if any(not a.get(k) for k in ['id', 'token', 'refreshToken', 'otherId', 'circleId']):
            raise ValueError('Incomplete synthetic fixture')
    output = Path(os.environ['CAPACITY_OUTPUT'])
    started_at = time.monotonic()
    deadline = started_at + ramp + hold
    all_times, hold_times, lag = array('d'), array('d'), array('d')
    endpoints = defaultdict(lambda: {'times': array('d'), 'errors': 0, 'statuses': Counter()})
    counts = Counter()
    error_samples = []
    users_started, users_in_hold, successful_hold_users = set(), set(), set()
    active, peak_active = 0, 0
    inflight, peak_inflight = 0, 0
    stopped = False

    async def monitor():
        expected = time.monotonic() + .25
        while not stopped:
            await asyncio.sleep(max(0, expected - time.monotonic()))
            now = time.monotonic()
            lag.append(max(0, now - expected)*1000)
            expected = now + .25

    async def progress():
        while not stopped:
            await asyncio.sleep(5)
            print(json.dumps({'elapsed_seconds': round(time.monotonic()-started_at), 'active_users': active,
                              'peak_active_users': peak_active, 'requests': counts['requests'],
                              'errors': counts['errors'], 'hold_requests': counts['hold_requests']}), flush=True)

    timeout = aiohttp.ClientTimeout(total=10, connect=5)
    connector = aiohttp.TCPConnector(limit=0, keepalive_timeout=15)
    async with aiohttp.ClientSession(connector=connector, timeout=timeout, trust_env=False) as client:
        async def user(ordinal, original):
            nonlocal active, peak_active
            await asyncio.sleep(max(0, started_at + ramp*ordinal/vus - time.monotonic()))
            account = dict(original)
            active += 1; peak_active = max(peak_active, active); users_started.add(account['id'])
            origin = origins[ordinal % len(origins)]
            ip = f'198.18.{ordinal//250}.{ordinal%250+1}'
            cycle, next_refresh = 0, 0

            async def request(path, name, body=None, content_type=None, read_json=False):
                nonlocal inflight, peak_inflight
                before = time.monotonic()
                in_hold = started_at+ramp <= before < deadline
                headers = {'Authorization': 'Bearer '+account['token']}
                if os.environ.get('SYNTHETIC_CLIENT_IPS') == '1': headers['X-Forwarded-For'] = ip
                if content_type: headers['Content-Type'] = content_type
                status, data, raw = 0, None, b''
                inflight += 1; peak_inflight = max(peak_inflight, inflight)
                try:
                    async with client.request('GET' if body is None else 'POST', origin+path, data=body, headers=headers) as response:
                        status = response.status
                        raw = await response.read()
                        if read_json and status == 200: data = json.loads(raw)
                except (aiohttp.ClientError, asyncio.TimeoutError, ValueError) as error:
                    counts['exception_'+type(error).__name__] += 1
                    status = 0
                finally:
                    inflight -= 1
                elapsed = (time.monotonic()-before)*1000
                counts['requests'] += 1; counts['errors'] += status != 200
                if status != 200 and len(error_samples) < 20:
                    error_samples.append({'endpoint': name, 'status': status, 'response': raw[:200].decode('utf-8', errors='replace')})
                all_times.append(elapsed)
                endpoint = endpoints[name]; endpoint['times'].append(elapsed)
                endpoint['errors'] += status != 200; endpoint['statuses'][str(status)] += 1
                if in_hold:
                    hold_times.append(elapsed); counts['hold_requests'] += 1; counts['hold_errors'] += status != 200
                    users_in_hold.add(account['id'])
                    if status == 200: successful_hold_users.add(account['id'])
                return status, data

            try:
                while time.monotonic() < deadline:
                    before = time.monotonic()
                    if before >= next_refresh:
                        status, data = await request('/api/auth/refresh', 'session refresh',
                            json.dumps({'refreshToken': account['refreshToken']}), 'application/json', True)
                        if status != 200 or not data:
                            counts['cycles'] += 1; counts['overruns'] += time.monotonic()-before > 5
                            await asyncio.sleep(5); continue
                        account['token'] = data['accessToken']; account['refreshToken'] = data['refreshToken']
                        next_refresh = time.monotonic()+min(300, max(1, data['expiresIn']*.8))
                    await request('/api/network/calls/incoming', 'incoming calls')
                    if cycle % 3 == 0:
                        await request('/api/network/presence/heartbeat', 'heartbeat', '')
                        await request('/api/notifications/unread-count', 'notification count')
                        await request('/api/network/messages/conversations', 'inbox')
                        await request('/api/network/circles/unread-counts', 'circle unread')
                    if (ordinal+1) % 5 == 0:
                        await request(f"/api/network/messages/with/{account['otherId']}?limit=50", 'direct history')
                        await request(f"/api/network/circles/{account['circleId']}/posts?limit=50", 'circle history')
                    if cycle % 12 == 0:
                        await request('/api/network/circles', 'circle directory')
                        if os.environ.get('SYNTHETIC_WRITES') == '1' and (ordinal+1) % 10 == 0:
                            boundary = f'capacity-{ordinal}'
                            body = f'--{boundary}\r\nContent-Disposition: form-data; name="message"\r\n\r\nSynthetic capacity message {cycle}\r\n--{boundary}--\r\n'
                            await request(f"/api/network/messages/with/{account['otherId']}", 'send message', body, f'multipart/form-data; boundary={boundary}')
                    duration = time.monotonic()-before
                    counts['cycles'] += 1; counts['overruns'] += duration > 5
                    cycle += 1
                    await asyncio.sleep(min(max(0, 5-duration), max(0, deadline-time.monotonic())))
            finally:
                active -= 1

        monitor_task = asyncio.create_task(monitor()); progress_task = asyncio.create_task(progress())
        outcomes = await asyncio.gather(*(user(i, a) for i, a in enumerate(accounts[:vus])), return_exceptions=True)
        stopped = True
        monitor_task.cancel(); progress_task.cancel()
        await asyncio.gather(monitor_task, progress_task, return_exceptions=True)
    counts['task_errors'] = sum(isinstance(x, BaseException) for x in outcomes)
    error_rate = counts['errors']/max(1, counts['requests'])
    hold_error_rate = counts['hold_errors']/counts['hold_requests'] if counts['hold_requests'] else None
    overrun_rate = counts['overruns']/max(1, counts['cycles'])
    times, holding, lag_stats = percentiles(all_times), percentiles(hold_times), percentiles(lag)
    checks = {
        'all_distinct_users_started': len(users_started) == vus,
        'all_users_in_hold': len(users_in_hold) == vus,
        'all_users_successful_in_hold': len(successful_hold_users) == vus,
        'peak_simultaneous_users': peak_active == vus,
        'http_errors_below_1_percent': error_rate < .01,
        'hold_errors_below_1_percent': hold_error_rate is not None and hold_error_rate < .01,
        'p95_below_1500ms': times['count'] > 0 and times['p95_ms'] < 1500,
        'hold_p95_below_1500ms': holding['count'] > 0 and holding['p95_ms'] < 1500,
        'cycle_overruns_below_1_percent': overrun_rate < .01,
        'minimum_hold_throughput': counts['hold_requests'] >= math.floor(vus*hold*.5),
        'generator_lag_p95_below_100ms': lag_stats['count'] > 0 and lag_stats['p95_ms'] < 100,
        'no_task_errors': counts['task_errors'] == 0
    }
    for name in ['incoming calls', 'inbox', 'circle directory']:
        stats = percentiles(endpoints[name]['times'])
        checks[name+'_p95_below_1500ms'] = stats['count'] > 0 and stats['p95_ms'] < 1500
    result = {'passed': all(checks.values()), 'checks': checks, 'requested_users': vus, 'peak_active_users': peak_active, 'peak_inflight_requests': peak_inflight,
        'distinct_users_started': len(users_started), 'distinct_users_in_hold': len(users_in_hold),
        'successful_users_in_hold': len(successful_hold_users), 'ramp_seconds': ramp, 'hold_seconds': hold,
        'counts': dict(counts), 'error_rate': error_rate, 'hold_error_rate': hold_error_rate,
        'cycle_overrun_rate': overrun_rate, 'hold_requests_per_second': counts['hold_requests']/hold,
        'latency': times, 'hold_latency': holding, 'generator_event_loop_lag': lag_stats,
        'endpoints': {name: {**percentiles(v['times']), 'errors': v['errors'], 'statuses': dict(v['statuses'])} for name,v in endpoints.items()},
        'generator': 'Python asyncio/aiohttp', 'aiohttp_version': aiohttp.__version__, 'error_samples': error_samples}
    (output/'async-summary.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k != 'endpoints'}, indent=2), flush=True)
    return 0 if result['passed'] else 99


if __name__ == '__main__':
    sys.exit(asyncio.run(run()))
