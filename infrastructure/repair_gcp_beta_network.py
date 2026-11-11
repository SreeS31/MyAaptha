"""Repair only the initial beta IP allocation failure, preserving secrets and volumes."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import urllib.request


def repair():
    if os.name != 'posix' or os.geteuid() != 0:
        raise RuntimeError('Run only as root on the isolated beta VM')
    for path, expected in [('project/project-id', 'project-5c36c021-87c7-4cfc-833'),
                           ('instance/name', 'myaaptha-beta')]:
        request = urllib.request.Request('http://169.254.169.254/computeMetadata/v1/' + path,
                                         headers={'Metadata-Flavor': 'Google'})
        with urllib.request.urlopen(request, timeout=3) as response:
            if response.headers.get('Metadata-Flavor') != 'Google' or response.read().decode().strip() != expected:
                raise RuntimeError('Refusing to repair another host')
    root = Path('/opt/myaaptha-beta/runtime')
    if root.resolve() != root or not root.is_dir():
        raise RuntimeError('Expected the existing isolated beta runtime')
    if (root.parent / 'bootstrap.complete').exists():
        print('Beta bootstrap already completed; no repair applied.')
        return
    for name in ['.env', 'secrets/postgres_password', 'secrets/field_encryption_keys']:
        if not (root / name).is_file():
            raise RuntimeError('Expected existing protected beta configuration')
    source = Path(__file__).resolve().parent / 'production/compose.gcp-beta.yml'
    target = root / 'compose.gcp-beta.yml'
    previous = '945ef55d5c19e87484deaa117d7762d4dcee27d51094a5925658ed4bc6b8b5f3'
    updated = source.read_bytes()
    if b'ip_range: 172.30.0.128/25' not in updated:
        raise RuntimeError('Expected the reserved dynamic address pool fix')
    current = target.read_bytes()
    if current != updated:
        if hashlib.sha256(current).hexdigest() != previous:
            raise RuntimeError('Refusing to overwrite an unexpected runtime configuration')
        backup = root / 'compose.gcp-beta.yml.before-network-fix'
        if backup.exists():
            raise RuntimeError('Refusing to overwrite an existing configuration backup')
        shutil.copyfile(target, backup)
        target.write_bytes(updated)
    command = ['docker', 'compose', '--project-name', 'myaaptha-beta',
               '-f', 'docker-compose.prod.yml', '-f', 'compose.single-host.yml', '-f', 'compose.gcp-beta.yml']
    subprocess.run(command + ['config', '--quiet'], cwd=root, check=True)
    # No -v: preserve database and antivirus volumes, secrets and issued certificates.
    subprocess.run(command + ['down'], cwd=root, check=True)
    subprocess.run(command + ['up', '-d', '--wait'], cwd=root, check=True)
    subprocess.run(['certbot', 'renew', '--dry-run', '--run-deploy-hooks',
                    '--cert-name', '35-244-31-192.sslip.io'], check=True)
    (root.parent / 'bootstrap.complete').touch(mode=0o600)
    print('Beta network repaired; runtime healthy and certificate renewal verified.')


if __name__ == '__main__':
    repair()
