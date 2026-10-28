import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('package_workshop', ROOT/'tools/package_workshop.py')
pkg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pkg)


class WorkshopPackage(unittest.TestCase):
    def test_help_package_has_no_native_payload_and_has_exact_hashes(self):
        files = pkg.companion_files(ROOT, 'a'*40)
        self.assertEqual(json.loads(files['SOURCE.json'])['sourceCommit'], 'a'*40)
        self.assertIn(b'Manual installation', files['info.txt'])
        self.assertNotIn(b'STEAM_FILE_ID', files['info.txt'])
        self.assertIn(b'scripts_modinstalled', (ROOT/'workshop'/pkg.MOD/'README.md').read_bytes())
        self.assertTrue(all(not name.endswith(('.dll', '.exe', '.ps1')) for name in files))
        for line in files['SHA256SUMS.txt'].decode().splitlines():
            digest, name = line.split('  ', 1)
            self.assertEqual(digest, pkg.sha(files[name]))

    def test_output_is_complete_and_existing_upload_id_cannot_be_overwritten(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)/'upload'
            archive = pkg.package(ROOT, output, 'a'*40)
            with zipfile.ZipFile(archive) as stream:
                for name, data in pkg.companion_files(ROOT, 'a'*40).items():
                    self.assertEqual(stream.read(pkg.MOD+'/'+name), data)
            info = output/pkg.MOD/'info.txt'
            info.write_bytes(info.read_bytes()+b'\n[STEAM_FILE_ID:12345]\n')
            with self.assertRaises(FileExistsError):
                pkg.package(ROOT, output, 'b'*40)
            self.assertIn(b'STEAM_FILE_ID:12345', info.read_bytes())


if __name__ == '__main__':
    unittest.main()
