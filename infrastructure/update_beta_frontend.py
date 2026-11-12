"""Update only the isolated beta frontend to a scanned immutable image; rollback on failure."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request


def validate_image(image):
    if not re.fullmatch(r'ghcr[.]io/srees31/myaaptha-frontend@sha256:[a-f0-9]{64}', image):
        raise ValueError('Supply the scanned MyAaptha frontend registry digest')


def replace_image(contents, image):
    validate_image(image)
    lines = contents.splitlines()
    keys = [i for i, line in enumerate(lines) if line.startswith('MYAAPTHA_FRONTEND_IMAGE=')]
    if len(keys) != 1:
        raise ValueError('Expected exactly one existing frontend image setting')
    lines[keys[0]] = 'MYAAPTHA_FRONTEND_IMAGE=' + image
    return '\n'.join(lines) + '\n'


def update(image):
    validate_image(image)
    if os.name != 'posix' or os.geteuid() != 0:
        raise RuntimeError('Run as root on the isolated beta VM')
    for key, expected in [('project/project-id', 'project-5c36c021-87c7-4cfc-833'), ('instance/name', 'myaaptha-beta')]:
        request = urllib.request.Request('http://169.254.169.254/computeMetadata/v1/' + key, headers={'Metadata-Flavor': 'Google'})
        with urllib.request.urlopen(request, timeout=3) as response:
            if response.headers.get('Metadata-Flavor') != 'Google' or response.read().decode().strip() != expected:
                raise RuntimeError('Refusing to update another host')
    root = Path('/opt/myaaptha-beta/runtime')
    config = root / '.env'
    if root.resolve() != root or config.is_symlink() or not config.is_file():
        raise RuntimeError('Expected the existing protected beta runtime')
    before = config.read_text()
    after = replace_image(before, image)
    command = ['docker', 'compose', '--project-name', 'myaaptha-beta', '-f', 'docker-compose.prod.yml', '-f', 'compose.single-host.yml', '-f', 'compose.gcp-beta.yml']
    subprocess.run(['docker', 'pull', image], check=True)
    os.umask(0o077)
    if before != after:
        backup = root / ('.env.before-frontend-' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
        with backup.open('x') as output:
            output.write(before)

    def write(value):
        with tempfile.NamedTemporaryFile(mode='w', dir=root, prefix='.frontend-env-', delete=False) as output:
            output.write(value)
            temporary = Path(output.name)
        temporary.chmod(0o600)
        os.replace(temporary, config)

    try:
        write(after)
        subprocess.run(command + ['config', '--quiet'], cwd=root, check=True)
        subprocess.run(command + ['up', '-d', '--no-deps', '--wait', 'frontend'], cwd=root, check=True)
        actual = subprocess.check_output(['docker', 'inspect', '--format', '{{.Config.Image}}', 'myaaptha-beta-frontend-1'], text=True).strip()
        if actual != image:
            raise RuntimeError('Running frontend does not match the approved image')
        with urllib.request.urlopen('https://35-244-31-192.sslip.io/', timeout=20) as response:
            if response.status != 200:
                raise RuntimeError('Frontend HTTPS check failed')
        with urllib.request.urlopen('https://35-244-31-192.sslip.io/actuator/health', timeout=20) as response:
            if json.load(response).get('status') != 'UP':
                raise RuntimeError('Backend health check failed')
    except Exception:
        write(before)
        subprocess.run(command + ['up', '-d', '--no-deps', '--wait', 'frontend'], cwd=root, check=True)
        raise RuntimeError('Frontend verification failed; previous frontend configuration restored') from None
    print('Frontend updated and HTTPS/API health verified. Database, media, accounts and other services were not modified.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', required=True)
    args = parser.parse_args()
    update(args.image)
