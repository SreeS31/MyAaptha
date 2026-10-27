"""Disposable local capacity measurement with distinct sessions and native k6.
Never accepts an external database. Synthetic session signing keys exist only for
this disposable database; real authentication filters and token rotation stay on.
"""
import argparse
import concurrent.futures
from contextlib import closing
from contextlib import contextmanager
import sys
import base64
import hashlib
import hmac
import http.client
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import time
import urllib.request
import uuid
from smoke_tls import tls_services
from resource_sample import ResourceSampler

ROOT = Path(__file__).resolve().parent.parent


@contextmanager
def keep_test_awake():
    """Prevent automatic Windows sleep during measurement; restore on exit.

    Does not alter persistent power settings or prevent a manual suspend.
    """
    if os.name != 'nt':
        yield
        return
    import ctypes
    kernel = ctypes.windll.kernel32
    previous = kernel.SetThreadExecutionState(0x80000001)
    if not previous:
        raise RuntimeError('Could not prevent automatic sleep during the capacity test')
    try:
        yield
    finally:
        kernel.SetThreadExecutionState(previous)


def command(argv, **kwargs):
    result = subprocess.run(argv, text=True, capture_output=True, **kwargs)
    if result.returncode:
        raise RuntimeError(f'Command failed ({Path(argv[0]).name}); see saved logs if available')
    return result.stdout


def token(key, user, sid, kind, seconds):
    def b64(value):
        return base64.urlsafe_b64encode(value).decode().rstrip('=')
    now = int(time.time())
    payload = {'sub': str(user), 'username': f'capacity-user-{user}', 'role': 'USER',
               'type': kind, 'sid': sid, 'jti': str(uuid.uuid4()), 'iat': now, 'exp': now + seconds}
    unsigned = b64(b'{"alg":"HS512","typ":"JWT"}') + '.' + b64(json.dumps(payload).encode())
    return unsigned + '.' + b64(hmac.new(key.encode(), unsigned.encode(), hashlib.sha512).digest())


def run(args, tls_env, db):
    output = ROOT / '.tools' / ('capacity-' + time.strftime('%Y%m%d-%H%M%S'))
    output.mkdir(parents=True)
    print(f'Reports: {output}', flush=True)
    accounts = output / 'accounts.json'
    processes, logs = [], []
    report = {'status': 'preparing', 'sessions': args.sessions, 'background_accounts': args.records,
              'active_history_per_account': args.history, 'ramp_seconds': args.ramp,
              'hold_seconds': args.hold, 'warmup_seconds': args.warmup, 'replicas': args.replicas, 'postgres_memory_mib': args.db_memory, 'heap_mib_per_replica': args.heap,
              'fixture_auth': 'synthetic signed sessions; real database revocation and refresh',
              'client_ips': 'distinct benchmark IPs through loopback trusted-proxy boundary',
              'message_writes': True, 'generator': args.generator, 'started_at': time.strftime('%Y-%m-%dT%H:%M:%S%z')}
    def save():
        (output / 'result.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    save()
    env = tls_env.copy()
    env.update(DEBUG='false', TRACE='false', TRUSTED_PROXY_REGEX='127[.]0[.]0[.]1',
        JWT_SECRET=secrets.token_hex(32), MYAAPTHA_CORS_ALLOWED_ORIGINS='https://app.myaaptha.test',
        MYAAPTHA_PUBLIC_API_BASE_URL='https://app.myaaptha.test', MYAAPTHA_WEB_ORIGIN='https://app.myaaptha.test',
        MYAAPTHA_S3_BUCKET='myaaptha-validation', MYAAPTHA_S3_REGION='ap-south-1', SPRING_FLYWAY_ENABLED='false',
        MYAAPTHA_AUTH_RATE_LIMIT='10', MAX_CONNECTIONS='8192',
        MYAAPTHA_FIELD_ENCRYPTION_KEYS='primary=' + base64.b64encode(secrets.token_bytes(32)).decode(),
        ADMIN_MFA_ENCRYPTION_KEY=base64.b64encode(secrets.token_bytes(32)).decode())
    ports = list(range(18089, 18089 + args.replicas))
    def sql(value):
        return command(['docker', 'exec', '-i', db, 'psql', '-v', 'ON_ERROR_STOP=1', '-U', 'myaaptha', '-d', 'myaaptha', '-At'], input=value)
    def request(port, path, bearer=None):
        headers = {'Authorization': 'Bearer ' + bearer} if bearer else {}
        with urllib.request.urlopen(urllib.request.Request(f'http://127.0.0.1:{port}{path}', headers=headers), timeout=15) as response:
            return json.loads(response.read())
    try:
        command(['docker','update','--memory',f'{args.db_memory}m','--memory-swap',f'{args.db_memory}m',db])
        for port in ports:
            with socket.socket() as probe:
                probe.bind(('127.0.0.1', port))
        migration = subprocess.run(['java', '-Dloader.main=com.myaaptha.release.DatabaseMigration', '-cp', str(args.jar.resolve()),
            'org.springframework.boot.loader.launch.PropertiesLauncher'], env=env, text=True, capture_output=True)
        (output / 'migration.log').write_text(migration.stdout + migration.stderr, encoding='utf-8')
        if migration.returncode:
            raise RuntimeError('Migration failed')
        print('Seeding active accounts and circles...', flush=True)
        count = args.sessions + 1
        sql(f"""INSERT INTO users(username,password_hash,phone_verified) SELECT 'capacity-user-'||n,'disabled-synthetic-password',true FROM generate_series(1,{count}) n;
CREATE TABLE capacity_fixtures AS SELECT id AS user_id,
 LEAD(id,1,(SELECT MIN(id) FROM users)) OVER (ORDER BY id) AS other_id,
 ((ROW_NUMBER() OVER (ORDER BY id)-1)/50) AS group_id, NULL::bigint AS circle_id FROM users;
INSERT INTO circles(name,description,owner_user_id) SELECT 'capacity-circle-'||group_id,'Synthetic capacity circle',MIN(user_id) FROM capacity_fixtures GROUP BY group_id;
UPDATE capacity_fixtures f SET circle_id=c.id FROM circles c WHERE c.name='capacity-circle-'||f.group_id;
INSERT INTO circle_members(circle_id,user_id) SELECT circle_id,user_id FROM capacity_fixtures;
INSERT INTO relationships(owner_user_id,related_user_id,type,visibility_scope) SELECT user_id,other_id,'Friend','FRIENDS' FROM capacity_fixtures;
INSERT INTO direct_messages(sender_user_id,recipient_user_id,message) SELECT f.other_id,f.user_id,'Synthetic active history '||n FROM capacity_fixtures f CROSS JOIN generate_series(1,{args.history}) n;
INSERT INTO circle_posts(circle_id,author_user_id,message) SELECT c.id,c.owner_user_id,'Synthetic circle history '||n FROM circles c CROSS JOIN generate_series(1,100) n;
INSERT INTO direct_calls(caller_user_id,recipient_user_id,call_type,status,offer_sdp,created_at) SELECT f.other_id,f.user_id,'AUDIO','RINGING','synthetic expired offer',now()-interval '1 day' FROM capacity_fixtures f CROSS JOIN generate_series(1,20) n;""")
        print(f'Seeding {args.records:,} background accounts...', flush=True)
        sql(f"INSERT INTO users(username,password_hash) SELECT 'background-'||n,'disabled-synthetic-password' FROM generate_series(1,{args.records}) n;")
        first = int(sql("SELECT MIN(id) FROM users WHERE username LIKE 'background-%'").strip())
        print(f'Seeding {args.records:,} background messages...', flush=True)
        sql(f"INSERT INTO direct_messages(sender_user_id,recipient_user_id,message) SELECT {first}+(n%{args.records}),{first}+((n+1)%{args.records}),'Synthetic background history' FROM generate_series(1,{args.records}) n;")
        sql('ANALYZE;')
        for port in ports:
            log = (output / f'api-{port}.log').open('w', encoding='utf-8'); logs.append(log)
            process = subprocess.Popen(['java', f'-Xmx{args.heap}m', f'-Xlog:gc:file=gc-{port}.log:time,level,tags',
                '-jar', str(args.jar.resolve()), '--spring.profiles.active=prod', '--server.address=127.0.0.1', f'--server.port={port}'],
                env=env, cwd=output, stdout=log, stderr=subprocess.STDOUT)
            processes.append(process)
            for attempt in range(180):
                if process.poll() is not None:
                    raise RuntimeError('API startup failed')
                try:
                    request(port, '/actuator/health/readiness'); break
                except (OSError, ValueError):
                    time.sleep(1)
            else:
                raise RuntimeError('API readiness timeout')
            print(f'API replica {port} ready.', flush=True)
        # Mint after seeding/startup. Never put tokens or signing keys in command arguments/logs.
        members, rows = [], []
        for line in sql('SELECT user_id,other_id,circle_id FROM capacity_fixtures ORDER BY user_id').strip().splitlines():
            user, other, circle = map(int, line.split('|'))
            sid = str(uuid.uuid4())
            access = token(env['JWT_SECRET'], user, sid, 'access', 900)
            refresh = token(env['JWT_SECRET'], user, sid, 'refresh', 86400)
            members.append({'id': user, 'otherId': other, 'circleId': circle, 'token': access, 'refreshToken': refresh})
            fingerprint = hashlib.sha256(refresh.encode()).hexdigest()
            rows.append(f"('{fingerprint}',{user},'refresh',now()+interval '1 day','{sid}')")
        assert len(members) == count, "Unexpected accounts in disposable fixture database"
        for offset in range(0, len(rows), 500):
            sql('INSERT INTO auth_tokens(token,user_id,token_type,expires_at,session_id) VALUES ' + ','.join(rows[offset:offset+500]) + ';')
        sample = members[0]
        # Verify the production idle timeout exceeds the clients' polling interval.
        with closing(http.client.HTTPConnection('127.0.0.1', ports[0], timeout=10)) as connection:
            connection.request('GET', '/api/auth/health')
            response = connection.getresponse()
            assert response.status == 200
            response.read()
            original_socket = connection.sock
            assert original_socket is not None
            time.sleep(6)
            connection.request('GET', '/api/auth/health')
            response = connection.getresponse()
            assert response.status == 200
            response.read()
            assert connection.sock is original_socket, 'Polling should reuse the idle TCP connection'
        report['keep_alive_6_second_check'] = 'passed'
        page = request(ports[0], f"/api/network/messages/with/{sample['otherId']}?limit=50", sample['token'])
        assert len(page) == 50
        assert request(ports[-1], '/api/network/calls/incoming', sample['token']) == []
        assert len(request(ports[-1], '/api/network/circles', sample['token'])) == 1
        assert len(request(ports[-1], f"/api/network/circles/{sample['circleId']}/posts?limit=50", sample['token'])) == 50
        reader = members[1]
        read_path = f"/api/network/circles/{reader['circleId']}/posts?limit=50"
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            pages = list(executor.map(lambda port: request(port, read_path, reader['token']), [ports[0], ports[-1]]))
            assert all(len(page) == 50 for page in pages)
        snapshot_sql = f"SELECT count(*),min(read_at),max(read_at) FROM circle_post_reads WHERE user_id={reader['id']}"
        snapshot = sql(snapshot_sql).strip()
        assert snapshot.startswith('50|'), 'Concurrent read receipts must not duplicate rows'
        request(ports[0], read_path, reader['token'])
        assert sql(snapshot_sql).strip() == snapshot, 'Polling must preserve the original read timestamp'
        # Warm query/JIT paths before measuring steady-state active sessions.
        # Errors here fail preparation rather than being silently discarded.
        print(f'Warming API reads for {args.warmup}s before measurement.', flush=True)
        warm_until = time.monotonic() + args.warmup
        warm_requests = 0
        def warm_read(item):
            index, member = item
            port = ports[index % len(ports)]
            for path in ['/api/network/calls/incoming', '/api/network/messages/conversations', '/api/network/circles']:
                request(port, path, member['token'])
            return 3
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
            while time.monotonic() < warm_until:
                warm_requests += sum(executor.map(warm_read, enumerate(members[:20])))
        report['warmup_successful_requests'] = warm_requests
        accounts.write_text(json.dumps(members[:args.sessions]), encoding='utf-8')
        report.update(status='measuring', fixture_checks='passed', total_accounts=args.records+count,
                      direct_messages=args.records+count*args.history)
        save()
        load_env = os.environ.copy()
        load_env.update(ACCOUNTS_FILE=str(accounts), ORIGINS=','.join(f'http://127.0.0.1:{p}' for p in ports),
            VUS=str(args.sessions), RAMP_SECONDS=str(args.ramp), HOLD_SECONDS=str(args.hold), RAMP_DOWN='30s',
            SYNTHETIC_CLIENT_IPS='1', SYNTHETIC_WRITES='1', K6_NO_USAGE_REPORT='true', CAPACITY_OUTPUT=str(output))
        print(f'Measuring {args.sessions:,} distinct sessions: ramp {args.ramp}s, hold {args.hold}s.', flush=True)
        load_command = ([str(args.k6.resolve()), 'run', '--summary-export', str(output / 'k6-summary.json'), str(ROOT / 'testing/k6/concurrent-sessions.js')] if args.generator == 'k6' else [sys.executable, str(ROOT / 'testing/async_sessions.py')])
        with (output / 'load.log').open('w', encoding='utf-8') as log:
            load = subprocess.Popen(load_command, env=load_env, stdout=log, stderr=subprocess.STDOUT)
            processes.append(load)
            # Resource observations distinguish generator saturation from application capacity.
            sampler = ResourceSampler()
            observations = []
            low_memory_samples = 0
            report['process_ids'] = {'api': [p.pid for p in processes[:-1]], 'load_generator': load.pid}
            save()
            while load.poll() is None:
                observation = sampler.sample([p.pid for p in processes])
                observations.append(observation)
                low_memory_samples = low_memory_samples + 1 if observation.get('available_mib', 9999) < 256 else 0
                if low_memory_samples >= 3:
                    report['resource_abort'] = 'Less than 256 MiB physical memory available for 15 seconds'
                    save(); load.terminate()
                (output / 'resources.json').write_text(json.dumps(observations, indent=2), encoding='utf-8')
                time.sleep(5)
        report.update(status='passed' if load.returncode == 0 else 'failed', generator_exit_code=load.returncode,
                      finished_at=time.strftime('%Y-%m-%dT%H:%M:%S%z'))
        save()
        print(f"Measurement {report['status'].upper()}; detailed metrics in {output}", flush=True)
        if load.returncode:
            raise RuntimeError(report.get('resource_abort', 'Capacity thresholds failed; inspect load.log and summary'))
    except Exception as error:
        report.update(status='resource_limited' if report.get('resource_abort') else 'failed', error=str(error)); save()
        raise
    finally:
        accounts.unlink(missing_ok=True)
        for process in reversed(processes):
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=35)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
        for log in logs: log.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('jar', type=Path)
    parser.add_argument('--k6', type=Path)
    parser.add_argument('--generator', choices=['k6','async'], default='async')
    parser.add_argument('--sessions', type=int, default=5000)
    parser.add_argument('--records', type=int, default=3000000)
    parser.add_argument('--history', type=int, default=100)
    parser.add_argument('--ramp', type=int, default=180)
    parser.add_argument('--hold', type=int, default=180)
    parser.add_argument('--warmup', type=int, default=30)
    parser.add_argument('--replicas', type=int, default=2)
    parser.add_argument('--heap', type=int, default=256)
    parser.add_argument('--db-memory', type=int, default=768)
    args = parser.parse_args()
    if not (2 <= args.sessions <= 5000 and 2 <= args.records <= 3000000 and 100 <= args.history <= 2000
            and 0 <= args.warmup <= 300 and 256 <= args.db_memory <= 4096 and 1 <= args.replicas <= 4 and 256 <= args.heap <= 2048 and args.ramp >= 10 and args.hold >= 30):
        parser.error('Invalid bounded local test parameters')
    if args.generator == 'k6' and not args.k6:
        parser.error('--k6 is required for the k6 generator')
    with keep_test_awake(), tls_services() as (env, db):
        run(args, env, db)
