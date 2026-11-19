"""Install an owner-supplied contact OAuth app without printing its credentials."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request

ORIGIN = 'https://35-244-31-192.sslip.io'


def credentials(document, provider):
    value = document.get('web', document)
    client_id, secret = value.get('client_id', ''), value.get('client_secret', '')
    if not all(isinstance(v, str) and v.strip() and len(v) <= 1024 and
               not any(c in v for c in "\r\n\x00'") for v in (client_id, secret)):
        raise ValueError('A real OAuth client ID and secret are required')
    if provider == 'google' and not re.fullmatch(r'[A-Za-z0-9_-]+[.]apps[.]googleusercontent[.]com', client_id):
        raise ValueError('Expected a Google Web application client ID')
    expected = ORIGIN + '/api/contact-organizer/oauth/callback/' + provider
    if expected not in value.get('redirect_uris', []):
        raise ValueError('Register the exact beta contact callback before installing credentials')
    prefix = 'GOOGLE' if provider == 'google' else 'MICROSOFT'
    return {prefix + '_CONTACTS_CLIENT_ID': client_id,
            prefix + '_CONTACTS_CLIENT_SECRET': secret}


def replace_settings(before, settings):
    lines = before.splitlines()
    for key, value in settings.items():
        matches = [i for i, line in enumerate(lines) if line.startswith(key + '=')]
        if len(matches) > 1:
            raise ValueError('Duplicate contact-provider setting; review the protected configuration')
        entry = key + "='" + value + "'"
        if matches:
            lines[matches[0]] = entry
        else:
            lines.append(entry)
    return '\n'.join(lines) + '\n'


def install(path, provider):
    if os.name != 'posix' or os.geteuid() != 0:
        raise RuntimeError('Run as root on the existing beta VM')
    for key, expected in [('project/project-id', 'project-5c36c021-87c7-4cfc-833'),
                          ('instance/name', 'myaaptha-beta')]:
        req = urllib.request.Request('http://169.254.169.254/computeMetadata/v1/' + key,
                                     headers={'Metadata-Flavor': 'Google'})
        with urllib.request.urlopen(req, timeout=3) as response:
            if response.read().decode().strip() != expected:
                raise RuntimeError('Refusing to configure another host')
    source = Path(path)
    if (source.parent.resolve().parent != Path('/tmp') or
            not source.parent.name.startswith('myaaptha-contact-setup-')):
        raise ValueError('Use a dedicated private contact-setup directory under /tmp')
    if source.is_symlink() or not source.is_file() or source.stat().st_size > 16384:
        raise ValueError('Expected a small owner-supplied OAuth JSON file')
    if source.parent.stat().st_mode & 0o077:
        raise ValueError('Upload credentials into a private directory with mode 0700')
    settings = credentials(json.loads(source.read_text(encoding='utf-8-sig')), provider)
    root = Path('/opt/myaaptha-beta/runtime')
    config = root / '.env'
    if config.is_symlink() or not config.is_file():
        raise RuntimeError('Expected the protected beta runtime configuration')
    before = config.read_text()
    after = replace_settings(before, settings)
    os.umask(0o077)
    backups = root / 'release-backups'
    if backups.is_symlink():
        raise RuntimeError('Refusing a symlinked backup directory')
    backups.mkdir(mode=0o700, exist_ok=True)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    with (backups / ('contact-oauth-before-' + stamp + '.env')).open('x') as backup:
        backup.write(before)
    compose = ['docker', 'compose', '--project-name', 'myaaptha-beta', '-f',
               'docker-compose.prod.yml', '-f', 'compose.single-host.yml', '-f', 'compose.gcp-beta.yml']

    def write(value):
        with tempfile.NamedTemporaryFile(mode='w', dir=root, prefix='.contact-oauth-', delete=False) as output:
            output.write(value)
            name = Path(output.name)
        name.chmod(0o600)
        os.replace(name, config)

    try:
        write(after)
        subprocess.run(compose + ['config', '--quiet'], cwd=root, check=True)
        subprocess.run(compose + ['up', '-d', '--no-deps', '--wait', 'backend'], cwd=root, check=True)
        container = json.loads(subprocess.check_output(['docker', 'inspect', 'myaaptha-beta-backend-1']))[0]
        actual = dict(value.split('=', 1) for value in container['Config']['Env'] if '=' in value)
        if any(actual.get(key) != value for key, value in settings.items()):
            raise RuntimeError('The runtime does not expose the protected provider settings')
        # Do not print rendered compose configuration or container environment values.
        result = subprocess.check_output(['docker', 'exec', 'myaaptha-beta-backend-1',
                                         'wget', '-qO-', 'http://localhost:8080/actuator/health/readiness'])
        if json.loads(result).get('status') != 'UP':
            raise RuntimeError('Backend health check failed')
    except Exception:
        write(before)
        subprocess.run(compose + ['up', '-d', '--no-deps', '--wait', 'backend'], cwd=root, check=True)
        raise RuntimeError('Provider activation failed; previous settings restored') from None
    finally:
        source.unlink()
    print(provider.capitalize() + ' contact OAuth application installed; backend health passed. User sign-in and consent are still required.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--provider', required=True, choices=['google', 'microsoft'])
    parser.add_argument('--credentials-file', required=True)
    args = parser.parse_args()
    install(args.credentials_file, args.provider)
