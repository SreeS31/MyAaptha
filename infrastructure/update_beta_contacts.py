"""Update beta OAuth wiring and scanned application images with rollback guards."""
import argparse
import datetime
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request
from update_beta_interests import image, update


def overlay_change(before, candidate, expected):
    if not re.fullmatch(r'[a-f0-9]{64}', expected):
        raise ValueError('Expected a reviewed overlay checksum')
    if hashlib.sha256(before.encode()).hexdigest() != expected:
        raise ValueError('The runtime overlay changed; review it before deployment')
    if len(candidate) > 65536 or 'GOOGLE_CONTACTS_CLIENT_SECRET: ${GOOGLE_CONTACTS_CLIENT_SECRET:-}' not in candidate:
        raise ValueError('Expected the reviewed contact-provider overlay')
    return candidate


def rollout(backend, frontend, overlay, expected):
    image(backend, 'backend'); image(frontend, 'frontend')
    if os.name != 'posix' or os.geteuid() != 0:
        raise RuntimeError('Run as root on the existing beta VM')
    for key, value in [('project/project-id', 'project-5c36c021-87c7-4cfc-833'), ('instance/name', 'myaaptha-beta')]:
        request = urllib.request.Request('http://169.254.169.254/computeMetadata/v1/' + key,
                                         headers={'Metadata-Flavor': 'Google'})
        with urllib.request.urlopen(request, timeout=3) as response:
            if response.headers.get('Metadata-Flavor') != 'Google' or response.read().decode().strip() != value:
                raise RuntimeError('Refusing to update another host')
    root = Path('/opt/myaaptha-beta/runtime')
    target, source = root / 'compose.gcp-beta.yml', Path(overlay)
    if target.is_symlink() or source.is_symlink() or not target.is_file() or not source.is_file():
        raise ValueError('Expected regular reviewed compose files')
    before = target.read_text()
    after = overlay_change(before, source.read_text(), expected)
    backups = root / 'release-backups'
    if backups.is_symlink():
        raise RuntimeError('Refusing a symlinked backup directory')
    os.umask(0o077)
    backups.mkdir(mode=0o700, exist_ok=True)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup = backups / (stamp + '.compose.gcp-beta.yml')
    with backup.open('x') as output:
        output.write(before)

    def write(value):
        with tempfile.NamedTemporaryFile(mode='w', dir=root, prefix='.contacts-overlay-', delete=False) as output:
            output.write(value)
            path = Path(output.name)
        path.chmod(0o600)
        os.replace(path, target)

    compose = ['docker', 'compose', '--project-name', 'myaaptha-beta', '-f',
               'docker-compose.prod.yml', '-f', 'compose.single-host.yml', '-f', 'compose.gcp-beta.yml']
    try:
        write(after)
        subprocess.run(compose + ['config', '--quiet'], cwd=root, check=True)
        update(backend, frontend)
    except Exception:
        write(before)
        subprocess.run(compose + ['up', '-d', '--no-deps', '--wait', 'backend', 'frontend'], cwd=root, check=True)
        raise RuntimeError('Contact rollout failed; previous compose overlay restored') from None
    print('Contact OAuth wiring updated. Previous overlay: ' + str(backup))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backend', required=True)
    parser.add_argument('--frontend', required=True)
    parser.add_argument('--overlay', required=True)
    parser.add_argument('--expected-overlay-sha256', required=True)
    args = parser.parse_args()
    rollout(args.backend, args.frontend, args.overlay, args.expected_overlay_sha256)
