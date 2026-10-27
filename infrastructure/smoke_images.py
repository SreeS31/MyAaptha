"""Validate local release images without cloud credentials or publishing images."""
import json
import argparse
import secrets
import subprocess
import time
import urllib.error
import urllib.request


def docker(*args):
    return subprocess.run(['docker', *args], text=True, capture_output=True, check=True).stdout.strip()


def run(component=None):
    names = []
    try:
        for app, port, path in [('frontend', 3000, '/'), ('ai-agent', 8081, '/api/v1/ready')]:
            if component and component != app:
                continue
            image = f'myaaptha-{app}:local-validation'
            config = json.loads(docker('image', 'inspect', image))[0]['Config']
            assert config['User'] == '10001:10001', f'{app} must run as the application user'
            name = 'myaaptha-image-smoke-' + secrets.token_hex(6)
            docker('create', '--pull=never', '--name', name, '--read-only', '--cap-drop=ALL',
                   '--security-opt=no-new-privileges', '--tmpfs', '/tmp',
                   '-e', 'AI_ENV=production', '-p', f'127.0.0.1::{port}', image)
            names.append(name)
            docker('start', name)
            exposed = docker('port', name, f'{port}/tcp').rsplit(':', 1)[1]
            for _ in range(60):
                try:
                    with urllib.request.urlopen(f'http://127.0.0.1:{exposed}{path}', timeout=2) as response:
                        assert response.status == 200
                        if app == 'frontend':
                            assert "'strict-dynamic'" in response.headers['Content-Security-Policy']
                            assert 'MyAaptha' in response.read().decode()
                        break
                except (OSError, urllib.error.URLError):
                    time.sleep(1)
            else:
                raise AssertionError(f'{app} did not become ready')
        if component and component != 'backend':
            print(f'PASS: {component} non-root, read-only production startup')
            return
        backend = 'myaaptha-backend:local-validation'
        config = json.loads(docker('image', 'inspect', backend))[0]['Config']
        assert config['User'] == '10001:10001'
        # Intentionally missing all production credentials: startup must fail closed.
        name = 'myaaptha-image-smoke-' + secrets.token_hex(6)
        docker('create', '--pull=never', '--name', name, '--network=none', '--read-only',
               '--cap-drop=ALL', '--security-opt=no-new-privileges', '--tmpfs', '/tmp', backend)
        names.append(name)
        docker('start', name)
        result = subprocess.run(['docker', 'wait', name], text=True, capture_output=True, timeout=120, check=True)
        assert int(result.stdout.strip()) != 0, 'Backend must reject missing production configuration'
        print('PASS: non-root images, read-only frontend/AI startup, frontend CSP, backend rejects missing credentials')
    finally:
        for name in reversed(names):
            subprocess.run(['docker', 'rm', '-f', '-v', name], capture_output=True, check=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--component', choices=['backend', 'frontend', 'ai-agent'])
    run(parser.parse_args().component)
