"""Run production smoke checks on disposable TLS PostgreSQL/Redis containers.

Requires Docker (Linux containers), OpenSSL, keytool and Java (also used by CI).
No external database or cloud credentials are accepted or used.
"""
import argparse
from contextlib import contextmanager
import os
from pathlib import Path
import secrets
import socket
import subprocess
import tempfile
import time
from unittest.mock import patch
import smoke_backend


def execute(args, **kwargs):
    return subprocess.run(args, check=True, text=True, capture_output=True, **kwargs).stdout.strip()


@contextmanager
def tls_services():
    suffix = secrets.token_hex(6)
    containers = []
    allocated_ports=set()
    def local_port():
        while True:
            with socket.socket() as probe:
                probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
            if port not in allocated_ports:
                allocated_ports.add(port);return port
    with tempfile.TemporaryDirectory(prefix='myaaptha-tls-') as folder:
        root = Path(folder)
        execute(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
                 '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1',
                 '-keyout', str(root / 'server.key'), '-out', str(root / 'server.crt')])
        (root / '.postgresql').mkdir()
        (root / '.postgresql/root.crt').write_bytes((root / 'server.crt').read_bytes())
        (root / 'postgresql').mkdir()
        (root / 'postgresql/root.crt').write_bytes((root / 'server.crt').read_bytes())
        execute(['keytool', '-importcert', '-noprompt', '-alias', 'disposable-smoke',
                 '-file', str(root / 'server.crt'), '-keystore', str(root / 'trust.p12'),
                 '-storepass', 'disposable-test-only'])
        env = os.environ.copy()
        # pgJDBC uses APPDATA/postgresql on Windows and user.home/.postgresql on Unix.
        if os.name == 'nt':
            env['APPDATA'] = str(root)
        env.update(POSTGRES_HOST='127.0.0.1', POSTGRES_DB='myaaptha', POSTGRES_USER='myaaptha',
                   POSTGRES_PASSWORD=secrets.token_hex(24), POSTGRES_SSLMODE='verify-full',
                   REDIS_HOST='127.0.0.1', REDIS_PASSWORD=secrets.token_hex(24), REDIS_TLS='true',
                   JAVA_TOOL_OPTIONS=f'-Duser.home={root} -Djavax.net.ssl.trustStore={root / "trust.p12"} '
                                     '-Djavax.net.ssl.trustStorePassword=disposable-test-only')
        try:
            pg = 'myaaptha-smoke-pg-' + suffix
            execute(['docker', 'create', '--name', pg, '-p', f'127.0.0.1:{local_port()}:5432',
                     '-v', f'{root}:/certs:ro', '-e', 'POSTGRES_DB', '-e', 'POSTGRES_USER',
                     '-e', 'POSTGRES_PASSWORD', '--entrypoint', 'sh', 'postgres:17-alpine', '-c',
                     'cp /certs/server.* /tmp/; chown postgres:postgres /tmp/server.*; '
                     'chmod 600 /tmp/server.key; exec docker-entrypoint.sh postgres '
                     '-c ssl=on -c ssl_cert_file=/tmp/server.crt -c ssl_key_file=/tmp/server.key'], env=env)
            containers.append(pg)
            execute(['docker', 'start', pg])
            redis = 'myaaptha-smoke-redis-' + suffix
            # Redis reads a private temporary config, avoiding credentials in process arguments.
            (root / 'redis.conf').write_text('port 0\ntls-port 6379\ntls-cert-file /tmp/server.crt\n'
                'tls-key-file /tmp/server.key\ntls-ca-cert-file /tmp/server.crt\ntls-auth-clients no\n'
                'requirepass ' + env['REDIS_PASSWORD'] + '\n')
            execute(['docker', 'create', '--name', redis, '-p', f'127.0.0.1:{local_port()}:6379',
                     '-v', f'{root}:/certs:ro', '--entrypoint', 'sh', 'redis:7-alpine', '-c',
                     'cp /certs/server.* /certs/redis.conf /tmp/; chown redis:redis /tmp/server.* /tmp/redis.conf; '
                     'chmod 600 /tmp/server.key /tmp/redis.conf; exec docker-entrypoint.sh redis-server /tmp/redis.conf'])
            containers.append(redis)
            execute(['docker', 'start', redis])
            for name, key, port in [(pg, 'POSTGRES_PORT', '5432/tcp'), (redis, 'REDIS_PORT', '6379/tcp')]:
                env[key] = execute(['docker', 'port', name, port]).rsplit(':', 1)[1]
            for _ in range(60):
                result = subprocess.run(['docker', 'exec', pg, 'pg_isready', '-U', 'myaaptha'], capture_output=True)
                if result.returncode == 0:
                    break
                time.sleep(1)
            else:
                raise RuntimeError('Disposable PostgreSQL did not become ready')
            env['MYAAPTHA_TEST_REDIS_CONTAINER']=redis
            yield env, pg
        finally:
            for name in reversed(containers):
                subprocess.run(['docker', 'rm', '-f', '-v', name], capture_output=True, check=False)


def run(jar):
    with tls_services() as (env, pg):
        def check_dependencies(request,scrape_token):
            for dependency,key,container_port in ((env['MYAAPTHA_TEST_REDIS_CONTAINER'],'REDIS_PORT','6379/tcp'),
                                                   (pg,'POSTGRES_PORT','5432/tcp')):
                # These names come only from the disposable fixture above, never CLI input.
                execute(['docker','stop','--time','1',dependency])
                try:
                    assert request('/actuator/health/readiness',expected=503)['status']=='DOWN'
                    assert request('/actuator/health/liveness')['status']=='UP'
                    assert '# HELP ' in request('/actuator/prometheus',token=scrape_token,json_response=False)
                finally:
                    execute(['docker','start',dependency])
                if execute(['docker','port',dependency,container_port]).rsplit(':',1)[1]!=env[key]:
                    raise AssertionError('Disposable dependency host-port mapping changed on restart')
                for _ in range(60):
                    try:
                        if request('/actuator/health/readiness')['status']=='UP': break
                    except (OSError,AssertionError): pass
                    time.sleep(1)
                else: raise TimeoutError('Readiness did not recover after fixture dependency restart')
            print('PASS: Redis and PostgreSQL outages withdraw readiness, retain liveness/metrics, and recover')
        # The production process gets only this disposable environment; restore the caller afterward.
        with patch.dict(os.environ,env):
            smoke_backend.run(jar,18089,Path('.tools/smoke'),dependency_checks=check_dependencies)
        stored = execute(['docker', 'exec', pg, 'psql', '-U', 'myaaptha', '-d', 'myaaptha', '-At', '-c',
            "SELECT count(*) > 0 AND bool_and(amount LIKE 'enc:v1:primary:%' "
            "AND merchant LIKE 'enc:v1:primary:%' AND description LIKE 'enc:v1:primary:%') FROM financial_transactions"])
        if stored != 't':
            raise AssertionError('PostgreSQL private financial fields were not stored as ciphertext')
        print('PASS: real PostgreSQL stores financial values as ciphertext')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('jar', type=Path)
    run(parser.parse_args().jar.resolve())
