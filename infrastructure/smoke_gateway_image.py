"""Check the beta gateway's actual TLS response and hidden server banner locally."""
import argparse
from pathlib import Path
import secrets
import shutil
import ssl
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


def run(image):
    name = 'myaaptha-gateway-test-' + secrets.token_hex(6)
    def docker(*args):
        return subprocess.run(['docker', *args], capture_output=True, text=True, check=True, timeout=60).stdout.strip()
    docker('image', 'inspect', image)
    with tempfile.TemporaryDirectory(prefix='myaaptha-gateway-') as folder:
        root = Path(folder)
        cert = root / 'fullchain.pem'
        key = root / 'privkey.pem'
        openssl = shutil.which('openssl') or 'C:/Program Files/Git/usr/bin/openssl.exe'
        subprocess.run([openssl, 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
            '-subj', '/CN=beta.test', '-addext', 'subjectAltName=DNS:beta.test,IP:127.0.0.1',
            '-keyout', str(key), '-out', str(cert)], check=True, capture_output=True)
        config = root / 'default.conf'
        config.write_text((Path(__file__).parent / 'production/nginx-beta.conf.template').read_text().replace('BETA_HOSTNAME', 'beta.test'))
        created = False
        try:
            docker('create', '--pull=never', '--name', name, '-p', '127.0.0.1::443',
                '--mount', f'type=bind,source={config},target=/etc/nginx/conf.d/default.conf,readonly',
                '--mount', f'type=bind,source={root},target=/etc/letsencrypt/live/beta.test,readonly', image)
            created = True
            docker('start', name)
            port = docker('port', name, '443/tcp').rsplit(':', 1)[1]
            context = ssl.create_default_context(cafile=str(cert))
            for _ in range(30):
                try:
                    response = urllib.request.urlopen(f'https://127.0.0.1:{port}/', context=context, timeout=3)
                except urllib.error.HTTPError as error:
                    response = error  # No upstream apps in this fixture; a secured 502 is expected.
                except OSError:
                    time.sleep(1)
                    continue
                with response:
                    assert 'Server' not in response.headers
                    assert 'X-Powered-By' not in response.headers
                    assert response.headers['X-Content-Type-Options'] == 'nosniff'
                    assert response.headers['X-Frame-Options'] == 'DENY'
                    assert 'max-age=' in response.headers['Strict-Transport-Security']
                break
            else:
                raise RuntimeError('Beta gateway never accepted TLS connections')
            print('PASS: real gateway TLS, security headers, no Server or X-Powered-By banner')
        finally:
            if created:
                subprocess.run(['docker', 'rm', '-f', '-v', name], capture_output=True, timeout=60)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('image')
    run(parser.parse_args().image)
