"""Exercise PowerShell backup/restore guards with fake commands, never a database."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SHELL = shutil.which('powershell') or shutil.which('pwsh')
OPERATIONS = Path(__file__).with_name('operations').resolve()


def quoted(value):
    return "'" + str(value).replace("'", "''") + "'"


@unittest.skipUnless(SHELL, 'PowerShell is required for operational script tests')
class PostgresOperationsTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.calls = self.root / 'calls.txt'
        self.backups = self.root / 'backups'
        self.backups.mkdir()

    def run_script(self, name, arguments, *, dump_exit=0, empty=True, inspect_exit=0, restore_exit=0, configured=True):
        # Function definitions shadow the external programs. No network client is executed.
        database_url = quoted('fixture-only' if configured else '')
        source = f"""
$ErrorActionPreference='Stop'
$env:DATABASE_URL={database_url}
function global:pg_dump {{
  foreach ($required in @('--no-password','--format=custom','--no-owner')) {{ if ($args -notcontains $required) {{ throw 'Missing backup flag' }} }}
  Add-Content -LiteralPath {quoted(self.calls)} -Value 'dump'
  $target=($args | Where-Object {{ $_ -like '--file=*' }} | Select-Object -First 1).Substring(7)
  [IO.File]::WriteAllBytes($target, [Text.Encoding]::UTF8.GetBytes('fixture database dump'))
  $global:LASTEXITCODE={dump_exit}
}}
function global:psql {{
  foreach ($required in @('--no-password','--no-psqlrc','--set=ON_ERROR_STOP=1')) {{ if ($args -notcontains $required) {{ throw 'Missing inspect flag' }} }}
  Add-Content -LiteralPath {quoted(self.calls)} -Value 'inspect'
  $global:LASTEXITCODE={inspect_exit}
  Write-Output {'0' if empty else '1'}
}}
function global:pg_restore {{
  foreach ($required in @('--no-password','--single-transaction','--exit-on-error','--no-owner')) {{ if ($args -notcontains $required) {{ throw 'Missing restore flag' }} }}
  Add-Content -LiteralPath {quoted(self.calls)} -Value 'restore'
  $global:LASTEXITCODE={restore_exit}
}}
& {quoted(OPERATIONS / name)} {arguments}
"""
        driver = self.root / 'driver.ps1'
        driver.write_text(source, encoding='utf-8')
        return subprocess.run([SHELL, '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', str(driver)],
                              capture_output=True, text=True, timeout=30)

    def backup(self, **options):
        return self.run_script('backup-postgres.ps1', '-OutputDirectory ' + quoted(self.backups), **options)

    def make_dump(self):
        path = self.root / 'fixture.dump'
        path.write_bytes(b'fixture')
        Path(str(path) + '.sha256.json').write_text(json.dumps({'Hash': hashlib.sha256(b'fixture').hexdigest()}), encoding='utf-8')
        return path

    def restore(self, path, **options):
        return self.run_script('restore-postgres.ps1', '-BackupFile ' + quoted(path) + " -TargetDatabaseUrl 'fixture-only'", **options)

    def test_successful_backup_has_matching_checksum_and_unique_names(self):
        for _ in range(2):
            result = self.backup()
            self.assertEqual(0, result.returncode, result.stderr)
        dumps = list(self.backups.glob('*.dump'))
        self.assertEqual(2, len(dumps))
        for path in dumps:
            checksum = json.loads(Path(str(path) + '.sha256.json').read_text(encoding='utf-8-sig'))
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), checksum['Hash'].lower())
        self.assertEqual([], list(self.backups.glob('*.partial*')))

    def test_failed_backup_cleans_only_attempt_and_does_not_prune(self):
        existing = self.backups / 'myaaptha-existing.dump'
        existing.write_bytes(b'previous valid backup')
        os.utime(existing, (1, 1))
        result = self.backup(dump_exit=1)
        self.assertNotEqual(0, result.returncode)
        self.assertEqual([existing], list(self.backups.iterdir()))
        self.assertEqual(b'previous valid backup', existing.read_bytes())

    def test_missing_database_and_invalid_retention_do_not_invoke_dump(self):
        self.assertNotEqual(0, self.backup(configured=False).returncode)
        result = self.run_script('backup-postgres.ps1', '-OutputDirectory ' + quoted(self.backups) + ' -RetentionDays -1')
        self.assertNotEqual(0, result.returncode)
        self.assertFalse(self.calls.exists())

    def test_retention_removes_expired_dump_and_sidecar_only(self):
        expired = self.backups / 'myaaptha-old.dump'
        sidecar = Path(str(expired) + '.sha256.json')
        untouched = self.backups / 'operator-notes.txt'
        for path in (expired, sidecar, untouched):
            path.write_text('fixture', encoding='utf-8')
            os.utime(path, (1, 1))
        self.assertEqual(0, self.backup().returncode)
        self.assertFalse(expired.exists())
        self.assertFalse(sidecar.exists())
        self.assertTrue(untouched.exists())

    def test_restore_requires_valid_checksum_before_database_inspection(self):
        path = self.make_dump()
        sidecar = Path(str(path) + '.sha256.json')
        for content in (None, '{"Hash":"bad"}', '{"Hash":"' + '0' * 64 + '"}'):
            if content is None:
                sidecar.unlink()
            else:
                sidecar.write_text(content, encoding='utf-8')
            self.assertNotEqual(0, self.restore(path).returncode)
            self.assertFalse(self.calls.exists())

    def test_restore_rejects_nonempty_or_unreachable_database(self):
        path = self.make_dump()
        for options in (dict(empty=False), dict(inspect_exit=1)):
            self.calls.unlink(missing_ok=True)
            self.assertNotEqual(0, self.restore(path, **options).returncode)
            self.assertEqual('inspect', self.calls.read_text(encoding='utf-8-sig').strip())

    def test_restore_invokes_checked_transaction_only_after_preflight(self):
        path = self.make_dump()
        self.assertEqual(0, self.restore(path).returncode)
        self.assertEqual(['inspect', 'restore'], self.calls.read_text(encoding='utf-8-sig').splitlines())
        self.assertNotEqual(0, self.restore(path, restore_exit=1).returncode)


if __name__ == '__main__':
    unittest.main()
