"""Owner-operated password reset on the isolated beta VM; no public reset endpoint."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys
import urllib.request


def email_targets(values):
    values = [value.strip().lower() for value in values]
    if not 1 <= len(values) <= 2 or len(set(values)) != len(values):
        raise ValueError('Supply one or two distinct account emails')
    if any(len(value) > 254 or value.count('@') != 1 or
           any(c.isspace() or ord(c) < 32 for c in value) for value in values):
        raise ValueError('Invalid account email')
    return values


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def reset_sql(accounts, hashes):
    if not 1 <= len(accounts) <= 2 or len({int(a['id']) for a in accounts}) != len(accounts) or len(hashes) != len(accounts):
        raise ValueError('Expected one or two distinct existing accounts and matching hashes')
    if any(not re.fullmatch(r'\$2[aby]\$12\$[./A-Za-z0-9]{53}', value) for value in hashes):
        raise ValueError('Expected BCrypt cost-12 password hashes')
    ids = ','.join(str(int(a['id'])) for a in accounts)
    rows = ','.join(f"({int(a['id'])},{literal(a['email'].lower())},{literal(h)})"
                    for a, h in zip(accounts, hashes))
    return f"""BEGIN;
DO $reset$
DECLARE changed integer;
BEGIN
  PERFORM id FROM users WHERE id IN ({ids}) ORDER BY id FOR UPDATE;
  UPDATE users u SET password_hash=v.hash
    FROM (VALUES {rows}) AS v(id,email,hash)
    WHERE u.id=v.id AND lower(u.email)=v.email
      AND u.account_status='ACTIVE' AND u.identity_type='ACCOUNT';
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed <> {len(accounts)} THEN RAISE EXCEPTION 'Account eligibility changed; no passwords reset'; END IF;
  DELETE FROM auth_tokens WHERE user_id IN ({ids}) AND token_type='refresh';
END $reset$;
COMMIT;
"""


def sql(statement):
    result = subprocess.run(['docker', 'exec', '-i', '--user', 'postgres',
                             'myaaptha-beta-postgres-1', 'psql', '-X', '-qAt',
                             '-v', 'ON_ERROR_STOP=1', '-U', 'myaaptha', '-d', 'myaaptha'],
                            input=statement, text=True, capture_output=True, timeout=30)
    if result.returncode:
        raise RuntimeError('Database operation failed; password values and SQL were not printed')
    return result.stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--email', action='append', required=True)
    parser.add_argument('--apply', action='store_true', help='Reset the selected eligible existing accounts atomically')
    parser.add_argument('--show-passwords', action='store_true', help='Display credentials only in an interactive owner terminal')
    args = parser.parse_args()
    targets = email_targets(args.email)
    if os.name != 'posix' or os.geteuid() != 0:
        raise RuntimeError('Run as root on the beta VM through authorized operator access')
    if args.show_passwords and not sys.stdout.isatty():
        raise RuntimeError('Password display requires an interactive terminal; use SSH with a PTY')
    for key, expected in [('project/project-id', 'project-5c36c021-87c7-4cfc-833'),
                          ('instance/name', 'myaaptha-beta')]:
        request = urllib.request.Request('http://169.254.169.254/computeMetadata/v1/' + key,
                                         headers={'Metadata-Flavor': 'Google'})
        with urllib.request.urlopen(request, timeout=3) as response:
            if response.headers.get('Metadata-Flavor') != 'Google' or response.read().decode().strip() != expected:
                raise RuntimeError('Refusing to reset accounts on another host')
    values = ','.join(literal(value) for value in targets)
    result = sql("SELECT coalesce(json_agg(x),'[]'::json) FROM (SELECT id,username,email,account_status,identity_type "
                 f"FROM users WHERE lower(email) IN ({values}) ORDER BY id) x;")
    accounts = json.loads(result)
    missing = set(targets) - {a['email'].lower() for a in accounts}
    if missing:
        raise RuntimeError('No existing account found for: ' + ', '.join(sorted(missing)) + '. Nothing was changed; no accounts were created.')
    if len(accounts) != len(targets):
        raise RuntimeError('Email matches are ambiguous. Nothing was changed.')
    if any(a['account_status'] != 'ACTIVE' or a['identity_type'] != 'ACCOUNT' for a in accounts):
        raise RuntimeError('Selected accounts must be active sign-in accounts. Nothing was changed.')
    print('Verified existing accounts:', ', '.join(a['email'] for a in accounts))
    if not args.apply:
        print('Read-only check complete. Use --apply to reset the selected accounts.')
        return
    # Ubuntu 24.04 supplies Python 3.12/libxcrypt BCrypt; refuse weaker fallbacks.
    import warnings
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', DeprecationWarning)
        import crypt
    if crypt.METHOD_BLOWFISH not in crypt.methods:
        raise RuntimeError('BCrypt is unavailable; nothing was changed')
    passwords = ['Aa9!' + secrets.token_urlsafe(24) for _ in accounts]
    hashes = [crypt.crypt(p, crypt.mksalt(crypt.METHOD_BLOWFISH, rounds=4096)) for p in passwords]
    if any(crypt.crypt(p, h) != h for p, h in zip(passwords, hashes)):
        raise RuntimeError('BCrypt self-check failed; nothing was changed')
    statement = reset_sql(accounts, hashes)
    directory = Path('/opt/myaaptha-beta/password-resets')
    if directory.is_symlink() or directory.resolve() != directory:
        raise RuntimeError('Unexpected credentials directory')
    directory.mkdir(mode=0o700, exist_ok=True)
    directory.chmod(0o700)
    path = directory / (datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ-') + secrets.token_hex(4) + '.json')
    credentials = [{'email': a['email'], 'username': a['username'], 'password': p}
                   for a, p in zip(accounts, passwords)]
    with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'w') as output:
        json.dump({'status': 'prepared-not-yet-applied', 'accounts': credentials}, output, indent=2)
    sql(statement)
    with path.open('w') as output:
        json.dump({'status': 'passwords-reset', 'accounts': credentials}, output, indent=2)
    print('Selected passwords reset; existing refresh sessions revoked. Roles and MFA were unchanged.')
    print('Private owner-only credentials file:', path)
    if args.show_passwords:
        for account in credentials:
            print('\nEmail:', account['email'], '\nUsername:', account['username'], '\nNew password:', account['password'])
    print('No email was sent. Store the new passwords in your password manager; do not paste them into chat.')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
