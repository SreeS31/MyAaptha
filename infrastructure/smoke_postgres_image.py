"""Verify the patched PostgreSQL image initializes and drops root, using synthetic data."""
import argparse
import secrets
import subprocess
import time


def run(image):
    name = 'myaaptha-postgres-image-' + secrets.token_hex(6)
    def docker(*args):
        return subprocess.run(['docker', *args], check=True, capture_output=True, text=True, timeout=60).stdout.strip()
    try:
        docker('run', '-d', '--pull=never', '--name', name, '--network=none',
               '-e', 'POSTGRES_PASSWORD=' + secrets.token_hex(24), image)
        for _ in range(90):
            ready = subprocess.run(['docker', 'exec', name, 'pg_isready', '-U', 'postgres'], capture_output=True)
            if ready.returncode == 0:
                break
            time.sleep(1)
        else:
            raise RuntimeError('PostgreSQL did not initialize')
        assert docker('exec', name, 'psql', '-U', 'postgres', '-At', '-c',
                      'CREATE TABLE beta_image_probe(id int); INSERT INTO beta_image_probe VALUES(42); SELECT id FROM beta_image_probe;').endswith('42')
        # The daemon's PID 1 must run as postgres, not root.
        uid_line = next(x for x in docker('exec', name, 'cat', '/proc/1/status').splitlines() if x.startswith('Uid:'))
        assert set(uid_line.split()[1:]) == {'70'}, 'PostgreSQL must drop root privileges'
        print('PASS: patched PostgreSQL initializes, reads/writes synthetic data and runs as UID 70')
    finally:
        subprocess.run(['docker', 'rm', '-f', '-v', name], capture_output=True, timeout=60)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('image')
    run(parser.parse_args().image)
