"""Guarded beta backend/frontend rollout with a fresh PostgreSQL restore check."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request
import uuid


def image(value, component):
    if not re.fullmatch(r'ghcr[.]io/srees31/myaaptha-' + component + r'@sha256:[a-f0-9]{64}', value):
        raise ValueError('Use the scanned immutable ' + component + ' digest for this release')
    return value


def replace_images(contents, backend, frontend):
    image(backend, 'backend'); image(frontend, 'frontend')
    lines = contents.splitlines()
    for key, value in [('MYAAPTHA_BACKEND_IMAGE', backend), ('MYAAPTHA_FRONTEND_IMAGE', frontend)]:
        indexes = [i for i, line in enumerate(lines) if line.startswith(key + '=')]
        if len(indexes) != 1:
            raise ValueError('Expected one existing ' + key + ' setting')
        lines[indexes[0]] = key + '=' + value
    return '\n'.join(lines) + '\n'


def update(backend, frontend):
    image(backend, 'backend'); image(frontend, 'frontend')
    if os.name != 'posix' or os.geteuid() != 0:
        raise RuntimeError('Run as root on the existing beta VM')
    for key, expected in [('project/project-id', 'project-5c36c021-87c7-4cfc-833'), ('instance/name', 'myaaptha-beta')]:
        req = urllib.request.Request('http://169.254.169.254/computeMetadata/v1/' + key, headers={'Metadata-Flavor': 'Google'})
        with urllib.request.urlopen(req, timeout=3) as response:
            if response.headers.get('Metadata-Flavor') != 'Google' or response.read().decode().strip() != expected:
                raise RuntimeError('Refusing to change another host')
    root = Path('/opt/myaaptha-beta/runtime')
    config = root / '.env'
    if root.resolve() != root or config.is_symlink() or not config.is_file():
        raise RuntimeError('Expected the existing protected beta runtime')
    before = config.read_text()
    after = replace_images(before, backend, frontend)
    settings = dict(line.split('=', 1) for line in before.splitlines() if '=' in line and not line.startswith('#'))
    dbname, dbuser = settings.get('POSTGRES_DB', 'myaaptha'), settings.get('POSTGRES_USER', 'myaaptha')
    if not all(re.fullmatch(r'[a-z][a-z0-9_]{0,62}', value) for value in [dbname, dbuser]):
        raise RuntimeError('Unexpected database identifiers; review manually')
    compose = ['docker', 'compose', '--project-name', 'myaaptha-beta', '-f', 'docker-compose.prod.yml', '-f', 'compose.single-host.yml', '-f', 'compose.gcp-beta.yml']
    def run(args, **kwargs):
        return subprocess.run(args, cwd=root, check=True, **kwargs)
    def dc(*args, **kwargs):
        return run(compose + list(args), **kwargs)
    pg = ['docker', 'exec', '-i', 'myaaptha-beta-postgres-1', 'sh', '-c', 'export PGPASSWORD="$(cat /run/secrets/postgres_password)"; exec "$@"', 'sh']
    os.umask(0o077)
    backup_dir = root / 'release-backups'
    if backup_dir.is_symlink():
        raise RuntimeError('Backup directory must not be a symbolic link')
    backup_dir.mkdir(mode=0o700, exist_ok=True)
    backup_dir.chmod(0o700)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup = backup_dir / (stamp + '.dump')
    previous = backup_dir / (stamp + '.env')
    with previous.open('x') as output:
        output.write(before)
    run(['docker', 'pull', backend]); run(['docker', 'pull', frontend])
    def write(value):
        with tempfile.NamedTemporaryFile(mode='w', dir=root, prefix='.interests-env-', delete=False) as output:
            output.write(value); temporary = Path(output.name)
        temporary.chmod(0o600); os.replace(temporary, config)
    stopped = False
    try:
        dc('stop', 'backend'); stopped = True
        with backup.open('xb') as output:
            run(pg + ['pg_dump', '--username=' + dbuser, '--dbname=' + dbname, '--format=custom'], stdout=output)
        restore_db = 'myaaptha_releasecheck_' + uuid.uuid4().hex[:12]
        created = False
        try:
            run(pg + ['createdb', '--username=' + dbuser, restore_db]); created = True
            with backup.open('rb') as source:
                run(pg + ['pg_restore', '--username=' + dbuser, '--dbname=' + restore_db, '--exit-on-error'], stdin=source)
            query = 'SELECT COUNT(*) FROM users'
            original = subprocess.check_output(pg + ['psql', '--username=' + dbuser, '--dbname=' + dbname, '-Atc', query], cwd=root)
            restored = subprocess.check_output(pg + ['psql', '--username=' + dbuser, '--dbname=' + restore_db, '-Atc', query], cwd=root)
            if original != restored:
                raise RuntimeError('Restore user-count verification failed')
        finally:
            if created:
                run(pg + ['dropdb', '--username=' + dbuser, restore_db])
        write(after); dc('config', '--quiet')
        dc('run', '--rm', '--no-deps', 'migrate')
        dc('up', '-d', '--no-deps', '--wait', 'backend', 'frontend')
        for component, expected in [('backend', backend), ('frontend', frontend)]:
            actual = subprocess.check_output(['docker', 'inspect', '--format', '{{.Config.Image}}', 'myaaptha-beta-' + component + '-1'], text=True).strip()
            if actual != expected:
                raise RuntimeError('Running image does not match validated digest')
        with urllib.request.urlopen('https://35-244-31-192.sslip.io/actuator/health', timeout=30) as response:
            if json.load(response).get('status') != 'UP':
                raise RuntimeError('API health failed')
        with urllib.request.urlopen('https://35-244-31-192.sslip.io/interests', timeout=30) as response:
            if response.status != 200:
                raise RuntimeError('Interests page failed')
    except Exception:
        write(before)
        if stopped:
            dc('up', '-d', '--no-deps', '--wait', 'backend', 'frontend')
        raise RuntimeError('Rollout failed; previous application image settings restored. Inspect migration logs; never automatically restore the live database.') from None
    print('Backend/frontend updated; backup restored into a disposable database and user count verified. HTTPS/API health passed. Backup: ' + str(backup))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backend', required=True)
    parser.add_argument('--frontend', required=True)
    args = parser.parse_args()
    update(args.backend, args.frontend)
