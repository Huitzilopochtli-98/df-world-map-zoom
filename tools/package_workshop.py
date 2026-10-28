"""Prepare the Workshop help companion locally. Does not access Steam."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MOD = 'worldmap-zoom-companion'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def companion_files(root, revision):
    folder = root/'workshop'/MOD
    names = ('info.txt', 'README.md', 'scripts_modinstalled/worldmap-zoom-setup.lua')
    files = {name: (folder/name).read_bytes() for name in names}
    files['preview.png'] = (root/'fortress-inspection.png').read_bytes()
    if len(files['preview.png']) >= 1024*1024:
        raise ValueError('Workshop preview must be below 1 MiB')
    files['LICENSE'] = (root/'LICENSE').read_bytes()
    files['THIRD_PARTY_NOTICES.md'] = (root/'THIRD_PARTY_NOTICES.md').read_bytes()
    if b'STEAM_FILE_ID' in files['info.txt']:
        raise ValueError('Source metadata must not include a publishing account item ID')
    files['SOURCE.json'] = (json.dumps({
        'version': '1.0.0',
        'sourceCommit': revision,
        'repository': 'https://github.com/Huitzilopochtli-98/df-world-map-zoom',
        'kind': 'Workshop setup companion; native plugin needs manual installation',
    }, indent=2)+'\n').encode()
    files['SHA256SUMS.txt'] = ''.join(
        f'{sha(data)}  {name}\n' for name, data in sorted(files.items())
    ).encode()
    return files


def package(root, output, revision):
    if output.exists():
        raise FileExistsError('Use a new output directory; existing upload metadata must be preserved.')
    files = companion_files(root, revision)
    output.mkdir(parents=True)
    for name, data in files.items():
        target = output/MOD/name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    for name in ('WORKSHOP_DESCRIPTION.bbcode', 'PUBLISHING.md'):
        shutil.copyfile(root/'workshop'/name, output/name)
    archive = output/'WorldMapZoom-1.0.0-Workshop-Companion.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as stream:
        for name, data in sorted(files.items()):
            entry = zipfile.ZipInfo(MOD+'/'+name, (2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            stream.writestr(entry, data)
    (output/'SHA256SUMS.txt').write_text(f'{sha(archive.read_bytes())}  {archive.name}\n', encoding='utf-8', newline='\n')
    return archive


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT/'dist/workshop-1.0.0')
    args = parser.parse_args()
    if subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT).strip():
        raise SystemExit('Commit the companion source before packaging.')
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    print(package(ROOT, args.output.resolve(), revision))
    print('Prepared locally. No Steam account was accessed and nothing was uploaded.')


if __name__ == '__main__':
    main()
