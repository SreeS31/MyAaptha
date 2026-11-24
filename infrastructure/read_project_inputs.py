"""Read only the saved project setup board on the existing beta VM.

Run with sudo python3 after copying this helper to the VM. Never reads the
referenced Secret Manager versions. stdout contains public IDs, decisions and
secret references, not credential contents or encryption keys.
"""
import base64
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request


FIELDS = {
    'meta': {'status', 'appId', 'accountType', 'credentials'},
    'firebase': {'status', 'projectId', 'appId', 'credentials'},
    'apns': {'status', 'teamId', 'bundleId', 'environment', 'credentials'},
    'encryption': {'mode', 'recovery'},
    'devices': {'android', 'ios'},
    'community-parity': {'priority'},
}


def read():
    if os.name != 'posix' or os.geteuid() != 0:
        raise RuntimeError('Run only as root on the beta VM')
    for key, expected in [('project/project-id', 'project-5c36c021-87c7-4cfc-833'), ('instance/name', 'myaaptha-beta')]:
        request = urllib.request.Request('http://169.254.169.254/computeMetadata/v1/' + key, headers={'Metadata-Flavor': 'Google'})
        with urllib.request.urlopen(request, timeout=3) as response:
            if response.headers.get('Metadata-Flavor') != 'Google' or response.read().decode().strip() != expected:
                raise RuntimeError('Unexpected host')
    root = Path('/opt/myaaptha-beta/runtime')
    if root.resolve() != root or (root / '.env').is_symlink():
        raise RuntimeError('Unexpected runtime')
    settings = dict(line.split('=', 1) for line in (root / '.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
    user, database = settings.get('POSTGRES_USER', 'myaaptha'), settings.get('POSTGRES_DB', 'myaaptha')
    if not all(re.fullmatch(r'[a-z][a-z0-9_]{0,62}', value) for value in [user, database]):
        raise RuntimeError('Unexpected database identifiers')
    query = "SELECT COALESCE(json_agg(t), '[]'::json) FROM (SELECT task_key,input_data,ready,version,updated_at FROM project_input_tasks ORDER BY task_key) t"
    command = ['docker', 'exec', 'myaaptha-beta-postgres-1', 'sh', '-c', 'export PGPASSWORD="$(cat /run/secrets/postgres_password)"; exec "$@"', 'sh', 'psql', '--username=' + user, '--dbname=' + database, '-Atc', query]
    rows = json.loads(subprocess.check_output(command, stderr=subprocess.PIPE))
    keys = None
    output = []
    for row in rows:
        if row['task_key'] not in FIELDS:
            raise RuntimeError('Unknown setup task')
        value = row['input_data']
        if value.startswith('enc:v1:'):
            from cryptography.hazmat.primitives.ciphers.aead import AESGCM
            if keys is None:
                raw = subprocess.check_output(['docker', 'exec', 'myaaptha-beta-backend-1', 'cat', '/run/secrets/field_encryption_keys'], stderr=subprocess.PIPE).decode().strip()
                keys = dict(entry.strip().split('=', 1) for entry in raw.split(','))
            _, _, key_id, encoded = value.split(':', 3)
            header = 'enc:v1:' + key_id + ':'
            sealed = base64.b64decode(encoded, validate=True)
            value = AESGCM(base64.b64decode(keys[key_id], validate=True)).decrypt(sealed[:12], sealed[12:], header.encode()).decode()
        elif value.startswith('enc:'):
            raise RuntimeError('Unsupported encryption version')
        values = json.loads(value)
        if not isinstance(values, dict) or set(values) - FIELDS[row['task_key']]:
            raise RuntimeError('Unexpected setup fields')
        for key, item in values.items():
            if not isinstance(item, str) or len(item) > 300 or any(ord(char) < 32 for char in item):
                raise RuntimeError('Unexpected setup value')
            if key == 'credentials' and not re.fullmatch(r'projects/[A-Za-z0-9._:-]+/secrets/[A-Za-z0-9_-]+/versions/(latest|[0-9]+)', item):
                raise RuntimeError('Expected a secret reference')
        output.append({key: row[key] for key in ['task_key', 'ready', 'version', 'updated_at']} | {'values': values})
    return {'savedTasks': output, 'unsavedTasks': sorted(set(FIELDS) - {row['task_key'] for row in rows}),
            'encryptionReaderAvailable': importlib.util.find_spec('cryptography') is not None}


if __name__ == '__main__':
    try:
        print(json.dumps(read(), indent=2))
    except Exception as error:
        # Do not print exception arguments or traceback containing sensitive data.
        raise SystemExit('Project inputs could not be read: ' + type(error).__name__) from None
