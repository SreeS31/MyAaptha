"""Run the packaged production API against an isolated database configured via env.

Creates test accounts and a test circle. NEVER point this at a production database.
This test runs common migrations, then starts the real prod profile with migrations
disabled and schema validation enabled. No cloud/provider credentials are needed.
"""
import argparse
import base64
import json
import os
import secrets
import socket
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path

def run(jar, port, log_directory, dependency_checks=None):
    # Detect a conflicting listener before starting Java or touching its endpoints.
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', port))
    env = os.environ.copy()
    env.update(DEBUG='false', TRACE='false', TRUSTED_PROXY_REGEX='127[.]0[.]0[.]1',JWT_SECRET=secrets.token_hex(32), MYAAPTHA_CORS_ALLOWED_ORIGINS='https://app.myaaptha.test',
        MYAAPTHA_FIELD_ENCRYPTION_KEYS='primary=' + base64.b64encode(secrets.token_bytes(32)).decode(),
        ADMIN_MFA_ENCRYPTION_KEY=base64.b64encode(secrets.token_bytes(32)).decode(),
        MYAAPTHA_PUBLIC_API_BASE_URL='https://app.myaaptha.test', MYAAPTHA_WEB_ORIGIN='https://app.myaaptha.test',
        MYAAPTHA_S3_BUCKET='myaaptha-validation', MYAAPTHA_S3_REGION='ap-south-1', SPRING_FLYWAY_ENABLED='false',
        MYAAPTHA_METRICS_SCRAPE_TOKEN=secrets.token_urlsafe(48))
    log_directory.mkdir(parents=True, exist_ok=True)
    with (log_directory / 'migration.log').open('w') as log:
        subprocess.run(['java', '-Dloader.main=com.myaaptha.release.DatabaseMigration', '-cp', str(jar),
            'org.springframework.boot.loader.launch.PropertiesLauncher'], env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
    with (log_directory / 'encryption.log').open('w') as log:
        subprocess.run(['java', '-Dloader.main=com.myaaptha.release.EncryptSensitiveFields', '-cp', str(jar),
            'org.springframework.boot.loader.launch.PropertiesLauncher'], env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
    origin = f'http://127.0.0.1:{port}'
    def request(path, method='GET', body=None, token=None, expected=200, json_response=True):
        headers = {'Content-Type': 'application/json'}
        if token: headers['Authorization'] = 'Bearer ' + token
        req = urllib.request.Request(origin + path, data=json.dumps(body).encode() if body is not None else None,
                                     method=method, headers=headers)
        try:
            response = urllib.request.urlopen(req, timeout=10)
        except urllib.error.HTTPError as ex:
            response = ex
        with response:
            payload = response.read()
            if response.code != expected:
                raise AssertionError(f'{method} {path}: expected {expected}, got {response.code}')
            return (json.loads(payload) if json_response else payload.decode('utf-8')) if payload else None
    with (log_directory / 'production-startup.log').open('w') as log:
        process = subprocess.Popen(['java', '-jar', str(jar), '--spring.profiles.active=prod',
            '--server.address=127.0.0.1', f'--server.port={port}'], env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            for _ in range(120):
                if process.poll() is not None: raise RuntimeError('Production API exited; inspect production-startup.log')
                try:
                    request('/actuator/health/readiness'); break
                except (OSError, AssertionError): time.sleep(1)
            else: raise TimeoutError('Production readiness timed out')
            request('/actuator/health/liveness')
            request('/api/network/circles', expected=401)
            def member():
                name = 'smoke' + secrets.token_hex(6)
                password = secrets.token_hex(16)
                request('/api/users', 'POST', {'username': name, 'phoneNumber': '+1999' + str(secrets.randbelow(10**10)).zfill(10), 'password': password})
                session = request('/api/auth/login', 'POST', {'identifier': name, 'password': password})
                return session
            first, second = member(), member()
            request('/actuator/prometheus', expected=401)
            request('/actuator/prometheus', token=first['accessToken'], expected=403)
            request('/actuator/info', token=first['accessToken'], expected=403)
            scrape_token=env['MYAAPTHA_METRICS_SCRAPE_TOKEN']
            assert '# HELP ' in request('/actuator/prometheus', token=scrape_token, json_response=False)
            request('/api/auth/me', token=scrape_token, expected=401)
            request('/actuator/info', token=scrape_token, expected=401)
            assert 'components' not in request('/actuator/health/readiness')
            request('/api/users', token=first['accessToken'], expected=403)
            request('/api/dashboard/summary', token=first['accessToken'], expected=403)
            circle = request('/api/network/circles', 'POST', {'name': 'Deployment smoke circle', 'description': 'Isolated validation'}, first['accessToken'])
            own = request('/api/network/circles', token=first['accessToken'])
            other = request('/api/network/circles', token=second['accessToken'])
            assert any(item['id'] == circle['id'] for item in own)
            assert all(item['id'] != circle['id'] for item in other), 'Cross-user circle exposure'
            request(f"/api/network/circles/{circle['id']}/posts", token=second['accessToken'], expected=403)
            transaction = request('/api/finance/transactions', 'POST', {
                'amount': 12.34, 'direction': 'EXPENSE', 'category': 'OTHER',
                'merchant': 'Isolated encryption fixture', 'description': 'Synthetic private transaction'
            }, first['accessToken'])
            assert transaction['amount'] == 12.34
            own_finance = request('/api/finance/summary', token=first['accessToken'])
            assert any(item['id'] == transaction['id'] and item['amount'] == 12.34 for item in own_finance['transactions'])
            assert request('/api/finance/summary', token=second['accessToken'])['transactions'] == []
            request(f"/api/finance/transactions/{transaction['id']}", 'DELETE', token=second['accessToken'], expected=404)
            refreshed = request('/api/auth/refresh', 'POST', {'refreshToken': first['refreshToken']})
            request('/api/auth/me', token=refreshed['accessToken'])
            if dependency_checks:
                dependency_checks(request,scrape_token)
            print('PASS: migrations, production startup/schema, probes, registration/login/refresh, administration denial, cross-user circles and encrypted finance round trip/isolation')
            print('PASS: metrics denies anonymous/members; scoped scraper works without account or metadata access')
        finally:
            process.terminate()
            try: process.wait(timeout=20)
            except subprocess.TimeoutExpired: process.kill(); process.wait()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('jar', type=Path)
    parser.add_argument('--port', type=int, default=18089)
    parser.add_argument('--logs', type=Path, default=Path('.tools/smoke'))
    args = parser.parse_args()
    run(args.jar.resolve(), args.port, args.logs)
