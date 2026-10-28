"""Release packaging must reject mismatched binaries and incomplete payloads."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('package_release', ROOT/'tools/package_release.py')
pkg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pkg)


class ReleasePackaging(unittest.TestCase):
    def setUp(self):
        # Synthetic bytes only: standalone CI does not need game or plugin DLLs.
        self.native = b'validated-test-plugin'
        self.source = {
            'compatibility.json': b'{"modVersion":"test"}',
            'release/test.json': json.dumps({
                'version': 'test', 'nativeDllSha256': pkg.sha(self.native),
                'nativeValidation': 'synthetic', 'note': 'test fixture',
            }).encode(),
            'payload.json': json.dumps([pkg.DLL, 'hack/lua/test.lua']).encode(),
            'hack/lua/test.lua': b'-- fixture\n',
        }

    def test_hashes_bind_source_and_native(self):
        version, files = pkg.release_files(self.source, self.native, 'a'*40)
        provenance = json.loads(files['PROVENANCE.json'])
        self.assertEqual(version, 'test')
        self.assertEqual(provenance['sourceCommit'], 'a'*40)
        self.assertEqual(provenance['nativeDllSha256'], pkg.sha(files[pkg.DLL]))
        for line in files['SHA256SUMS.txt'].decode().splitlines():
            digest, name = line.split('  ', 1)
            self.assertEqual(digest, pkg.sha(files[name]))

    def test_rejects_wrong_native_binary(self):
        with self.assertRaisesRegex(ValueError, 'validated native hash'):
            pkg.release_files(self.source, b'wrong binary', 'a'*40)

    def test_rejects_missing_payload(self):
        del self.source['hack/lua/test.lua']
        with self.assertRaisesRegex(ValueError, 'Missing installer payload'):
            pkg.release_files(self.source, self.native, 'a'*40)

    def test_rejects_duplicate_payload(self):
        self.source['payload.json'] = json.dumps([pkg.DLL, pkg.DLL]).encode()
        with self.assertRaisesRegex(ValueError, 'Invalid payload'):
            pkg.release_files(self.source, self.native, 'a'*40)

    def test_rejects_unsafe_archive_paths(self):
        for path in ('../outside', '/absolute', 'C:/drive', 'x/../y', 'x\\y', './x', 'x//y'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                pkg.safe_path(path)

    def test_zip_roundtrip_is_deterministic_and_wont_overwrite(self):
        with tempfile.TemporaryDirectory() as folder:
            one, two = Path(folder)/'one.zip', Path(folder)/'two.zip'
            files = {'hack/a.lua': b'-- test\n'}
            pkg.write_zip(one, 'WorldMapZoom', files)
            pkg.write_zip(two, 'WorldMapZoom', files)
            self.assertEqual(one.read_bytes(), two.read_bytes())
            with zipfile.ZipFile(one) as archive:
                self.assertEqual(archive.read('WorldMapZoom/hack/a.lua'), files['hack/a.lua'])
            with self.assertRaises(FileExistsError):
                pkg.write_zip(one, 'WorldMapZoom', files)


if __name__ == '__main__':
    unittest.main()
