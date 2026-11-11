"""Initialize a fresh isolated Linux beta runtime. Never reuse production secrets/data.

Run as root on the reviewed beta VM only, with an image map from scan-gated CI
and separately scanned support images. Does not install packages or change cloud IAM.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import urllib.request

IMAGE_NAMES = ('backend', 'frontend', 'ai', 'postgres', 'redis', 'gateway', 'clamav')


def validate(images, domain, bucket, project):
    if set(images) != set(IMAGE_NAMES):
        raise ValueError('Supply exactly the seven reviewed application/support images')
    for image in images.values():
        if not isinstance(image, str) or not re.fullmatch(r'[a-z0-9][a-z0-9./:_-]*@sha256:[a-f0-9]{64}', image):
            raise ValueError('Every image must be pinned to its scanned registry digest')
    if not re.fullmatch(r'[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?', domain) or '.' not in domain:
        raise ValueError('Supply a DNS hostname, without scheme or path')
    if not re.fullmatch(r'[a-z0-9][a-z0-9._-]{1,220}[a-z0-9]', bucket):
        raise ValueError('Supply a valid private GCS bucket')
    if not re.fullmatch(r'[a-z][a-z0-9-]{4,28}[a-z0-9]', project):
        raise ValueError('Supply the intended Google Cloud project ID')


def prepare(destination, images, domain, bucket, project):
    validate(images, domain, bucket, project)
    if os.name != 'posix' or os.geteuid() != 0:
        raise RuntimeError('Initialize only as root on the isolated Linux beta VM')
    if destination != Path('/opt/myaaptha-beta/runtime') or destination.resolve() != destination or destination.exists():
        raise RuntimeError('Refusing to overwrite or adopt any existing runtime')
    def metadata(path):
        request = urllib.request.Request('http://169.254.169.254/computeMetadata/v1/' + path,
                                         headers={'Metadata-Flavor': 'Google'})
        with urllib.request.urlopen(request, timeout=3) as response:
            if response.headers.get('Metadata-Flavor') != 'Google':
                raise RuntimeError('Expected Google Cloud instance metadata')
            return response.read().decode().strip()
    if metadata('project/project-id') != project or metadata('instance/name') != 'myaaptha-beta':
        raise RuntimeError('Initialize only the intended myaaptha-beta VM in the reviewed project')
    os.umask(0o077)
    destination.mkdir(parents=True, mode=0o700)
    protected = destination / 'secrets'
    certificates = destination / 'certs'
    protected.mkdir(mode=0o700)
    certificates.mkdir(mode=0o700)
    for name, value in {
        'postgres_password': secrets.token_hex(24),
        'redis_password': secrets.token_hex(24),
        'jwt_secret': secrets.token_hex(48),
        'field_encryption_keys': 'primary=' + base64.b64encode(secrets.token_bytes(32)).decode(),
        'admin_mfa_encryption_key': base64.b64encode(secrets.token_bytes(32)).decode(),
    }.items():
        file = protected / name
        file.write_text(value, encoding='utf-8')
        # Parent is root-only; read-only secret mounts must be readable by app UID 10001.
        file.chmod(0o444)

    def run(*args):
        subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

    ca_key = certificates / 'beta-ca.key'
    ca = certificates / 'postgres-ca.crt'
    run('openssl', 'req', '-x509', '-newkey', 'rsa:3072', '-nodes', '-days', '30',
        '-subj', '/CN=MyAaptha isolated beta CA', '-keyout', str(ca_key), '-out', str(ca))
    ca.chmod(0o644)
    for service, uid in [('postgres', 70), ('redis', 999)]:
        key = certificates / f'{service}-server.key'
        csr = certificates / f'{service}.csr'
        crt = certificates / f'{service}-server.crt'
        ext = certificates / f'{service}.ext'
        ext.write_text(f'subjectAltName=DNS:{service}\nextendedKeyUsage=serverAuth\n', encoding='utf-8')
        run('openssl', 'req', '-new', '-newkey', 'rsa:3072', '-nodes', '-subj', f'/CN={service}',
            '-keyout', str(key), '-out', str(csr))
        run('openssl', 'x509', '-req', '-in', str(csr), '-CA', str(ca), '-CAkey', str(ca_key),
            '-CAcreateserial', '-days', '30', '-sha256', '-extfile', str(ext), '-out', str(crt))
        key.chmod(0o600)
        os.chown(key, uid, uid)
        crt.chmod(0o644)
    password = (protected / 'redis_password').read_text()
    redis_config = protected / 'redis.conf'
    redis_config.write_text('port 0\ntls-port 6379\ntls-cert-file /etc/redis/tls/server.crt\n'
        'tls-key-file /etc/redis/tls/server.key\ntls-ca-cert-file /etc/redis/tls/ca.crt\n'
        'tls-auth-clients no\nmaxmemory 256mb\nmaxmemory-policy noeviction\nrequirepass ' + password + '\n', encoding='utf-8')
    redis_config.chmod(0o400)
    os.chown(redis_config, 999, 999)
    source = Path(__file__).resolve().parent / 'production'
    for name in ['docker-compose.prod.yml', 'compose.single-host.yml', 'compose.gcp-beta.yml', 'Caddyfile']:
        shutil.copyfile(source / name, destination / name)
    values = {
        'MYAAPTHA_DOMAIN': domain,
        'MYAAPTHA_FRONTEND_IMAGE': images['frontend'], 'MYAAPTHA_BACKEND_IMAGE': images['backend'],
        'MYAAPTHA_AI_IMAGE': images['ai'], 'POSTGRES_IMAGE': images['postgres'],
        'REDIS_IMAGE': images['redis'], 'MYAAPTHA_GATEWAY_IMAGE': images['gateway'], 'CLAMAV_IMAGE': images['clamav'],
        'POSTGRES_HOST': 'postgres', 'POSTGRES_DB': 'myaaptha', 'POSTGRES_USER': 'myaaptha',
        'REDIS_HOST': 'redis', 'REDIS_TLS': 'true', 'POSTGRES_SSLMODE': 'verify-full',
        'MYAAPTHA_GCS_BUCKET': bucket, 'GOOGLE_CLOUD_PROJECT': project,
        # Base Compose interpolates this S3 value before the GCS override is merged; unused by GCS.
        'MYAAPTHA_S3_BUCKET': bucket, 'TRUSTED_PROXY_REGEX': r'172[.]30[.]0[.](2|3)',
    }
    (destination / '.env').write_text(''.join(f'{key}={value}\n' for key, value in values.items()), encoding='utf-8')
    nginx = (source / 'nginx-beta.conf.template').read_text(encoding='utf-8').replace('BETA_HOSTNAME', domain)
    (destination / 'nginx-beta.conf').write_text(nginx, encoding='utf-8')
    if not Path('/etc/letsencrypt/live', domain, 'fullchain.pem').is_file():
        print('TLS certificate is not installed yet; issue it before starting the gateway.')
    command = 'docker compose --project-name myaaptha-beta -f docker-compose.prod.yml -f compose.single-host.yml -f compose.gcp-beta.yml'
    (destination / 'start.sh').write_text('#!/bin/sh\nset -eu\ncd /opt/myaaptha-beta/runtime\n' +
        command + ' config --quiet\n' + command + ' pull\n' + command + ' up -d --wait\n', encoding='utf-8')
    (destination / 'start.sh').chmod(0o700)
    # Only the backend needs VM metadata credentials. Other containers cannot reach them.
    firewall = destination / 'metadata-firewall.sh'
    firewall.write_text('#!/bin/sh\nset -eu\niptables -N DOCKER-USER 2>/dev/null || true\n'
        'iptables -C DOCKER-USER -d 169.254.169.254/32 ! -s 172.30.0.4/32 -j REJECT 2>/dev/null || '
        'iptables -I DOCKER-USER 1 -d 169.254.169.254/32 ! -s 172.30.0.4/32 -j REJECT\n', encoding='utf-8')
    firewall.chmod(0o700)
    override = Path('/etc/systemd/system/docker.service.d')
    override.mkdir(parents=True, exist_ok=True)
    unit = override / 'myaaptha-beta-metadata.conf'
    if unit.exists():
        raise RuntimeError('Refusing to overwrite an existing Docker metadata firewall override')
    unit.write_text('[Service]\nExecStartPre=/opt/myaaptha-beta/runtime/metadata-firewall.sh\n', encoding='utf-8')
    run(str(firewall))
    run('systemctl', 'daemon-reload')
    renewal = Path('/etc/letsencrypt/renewal-hooks/deploy')
    renewal.mkdir(parents=True, exist_ok=True)
    hook = renewal / 'myaaptha-beta-reload'
    if hook.exists():
        raise RuntimeError('Refusing to overwrite an existing certificate renewal hook')
    hook.write_text('#!/bin/sh\nset -eu\ncd /opt/myaaptha-beta/runtime\n' + command +
        ' exec -T gateway nginx -s reload\n', encoding='utf-8')
    hook.chmod(0o700)
    print('Prepared isolated beta runtime; secrets were generated on the VM and not printed.')
    print('Metadata credential isolation is installed before Docker startup, including reboots.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--images', required=True, type=Path)
    parser.add_argument('--domain', required=True)
    parser.add_argument('--bucket', required=True)
    parser.add_argument('--project', required=True)
    args = parser.parse_args()
    prepare(Path('/opt/myaaptha-beta/runtime'), json.loads(args.images.read_text()), args.domain, args.bucket, args.project)
