"""Verify installation recovery with synthetic files, without game binaries."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LinuxInstaller(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.package, self.game, self.hack = root/'package', root/'game', root/'hack'
        for path in (self.package, self.game, self.hack):
            path.mkdir()
        shutil.copy2(ROOT/'Install-linux.py', self.package)
        self.payload = json.loads((ROOT/'payload.json').read_text())
        (self.package/'payload.json').write_text(json.dumps(self.payload))
        for relative in self.payload:
            path = self.package/relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(relative.encode())
        for path in (self.game/'Dwarf Fortress.exe', self.hack/'dfhack.dll'):
            path.write_bytes(b'fake executable')
        digest = hashlib.sha256(b'fake executable').hexdigest()
        (self.package/'compatibility.json').write_text(json.dumps(dict(
            modVersion='test', gameSha256=digest, dfhackSha256=digest)))
        self.record = self.game/'dfhack-config/worldmap-zoom-install.json'

    def run_installer(self, *args, success=True):
        result = subprocess.run([sys.executable, str(self.package/'Install-linux.py'),
            '--game-path', str(self.game), '--hack-path', str(self.hack), *args],
            capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stdout+result.stderr)
        return result

    def target(self, relative):
        return self.hack/relative[5:] if relative.startswith('hack/') else self.game/relative

    def test_backup_idempotence_and_restore(self):
        target = self.target(self.payload[0])
        target.parent.mkdir(parents=True)
        target.write_bytes(b'original user script')
        self.run_installer()
        first = json.loads(self.record.read_text())
        self.assertTrue(first['complete'])
        self.assertEqual(len(first['files']), len(self.payload))
        self.run_installer()
        self.assertEqual(json.loads(self.record.read_text()), first)
        self.run_installer('--uninstall')
        self.assertEqual(target.read_bytes(), b'original user script')
        self.assertFalse(self.record.exists())
        self.assertFalse(self.target(self.payload[-1]).exists())

    def test_preserve_preexisting_and_later_modified_files(self):
        existing = self.target(self.payload[0])
        existing.parent.mkdir(parents=True)
        shutil.copy2(self.package/self.payload[0], existing)
        self.run_installer()
        modified = self.target(self.payload[1])
        modified.write_bytes(b'user edit after install')
        self.run_installer('--uninstall')
        self.assertEqual(existing.read_bytes(), (self.package/self.payload[0]).read_bytes())
        self.assertEqual(modified.read_bytes(), b'user edit after install')
        self.assertEqual(len(json.loads(self.record.read_text())['files']), 1)

    def test_reject_unmatched_executable_and_missing_payload(self):
        (self.game/'Dwarf Fortress.exe').write_bytes(b'wrong version')
        self.run_installer(success=False)
        self.assertFalse(self.record.exists())
        (self.game/'Dwarf Fortress.exe').write_bytes(b'fake executable')
        (self.package/self.payload[-1]).unlink()
        self.run_installer(success=False)
        self.assertFalse(self.target(self.payload[0]).exists())

    def test_failed_install_restores_originals(self):
        original = self.target(self.payload[0])
        original.parent.mkdir(parents=True)
        original.write_bytes(b'original user script')
        self.target(self.payload[-1]).mkdir(parents=True)
        self.run_installer(success=False)
        self.assertEqual(original.read_bytes(), b'original user script')
        self.assertFalse(self.target(self.payload[1]).exists())
        self.assertFalse(self.record.exists())


if __name__ == '__main__':
    unittest.main()
