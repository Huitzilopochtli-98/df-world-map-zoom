"""Package committed public source and the explicitly validated native DLL.

Does not compile, install, push, tag, or publish anything. Python 3.10+; Git.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DLL = 'hack/plugins/worldmap-zoom-render.plug.dll'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def safe_path(name):
    path = PurePosixPath(name)
    if (not name or '\\' in name or ':' in name or path.is_absolute() or
            any(part in ('', '.', '..') for part in name.split('/'))):
        raise ValueError('Invalid archive path: '+name)
    return name


def release_files(source, native, revision):
    """Bind a tagged source snapshot to the DLL accepted by its release profile."""
    compat = json.loads(source['compatibility.json'])
    version = compat['modVersion']
    profile = json.loads(source[f'release/{version}.json'])
    if profile['version'] != version or sha(native) != profile['nativeDllSha256'].lower():
        raise ValueError('DLL does not match this release\'s validated native hash. Build and test a new release profile first.')
    payload = json.loads(source['payload.json'])
    if DLL not in payload or len(payload) != len(set(payload)):
        raise ValueError('Invalid payload manifest')
    files = {safe_path(name): data for name, data in source.items()}
    files[DLL] = native
    for name in payload:
        if safe_path(name) not in files:
            raise ValueError('Missing installer payload: '+name)
    provenance = {
        'version': version,
        'sourceCommit': revision,
        'nativeDllSha256': sha(native),
        'nativeValidation': profile['nativeValidation'],
        'nativeBuildNote': profile['note'],
        'compatibility': compat,
        'payloadSha256': {name: sha(files[name]) for name in payload},
    }
    files['PROVENANCE.json'] = (json.dumps(provenance, indent=2)+'\n').encode()
    files['SHA256SUMS.txt'] = ''.join(
        f'{sha(data)}  {name}\n' for name, data in sorted(files.items())
    ).encode()
    return version, files


def write_zip(path, prefix, files):
    # Fixed entry times and permissions remove packaging-time differences.
    with path.open('xb') as stream, zipfile.ZipFile(stream, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name, data in sorted(files.items()):
            entry = zipfile.ZipInfo(prefix+'/'+safe_path(name), (2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, data)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--native-dll', type=Path, required=True)
    ap.add_argument('--output', type=Path, default=ROOT/'dist')
    args = ap.parse_args()

    def git(*args):
        return subprocess.check_output(['git', *args], cwd=ROOT)

    if git('status', '--porcelain', '--untracked-files=normal').strip():
        raise SystemExit('Commit the public source before packaging; the working tree must be clean.')
    revision = git('rev-parse', 'HEAD').decode().strip()
    snapshot = git('archive', '--format=zip', 'HEAD')
    with zipfile.ZipFile(io.BytesIO(snapshot)) as archive:
        source = {entry.filename: archive.read(entry) for entry in archive.infolist() if not entry.is_dir()}
    version, files = release_files(source, args.native_dll.read_bytes(), revision)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    binary_zip = output/f'WorldMapZoom-{version}-windows-x64.zip'
    source_zip = output/f'df-world-map-zoom-{version}-source.zip'
    checksum = output/'SHA256SUMS.txt'
    for path in (binary_zip, source_zip, checksum):
        if path.exists():
            raise SystemExit('Refusing to overwrite existing release asset: '+str(path))
    write_zip(source_zip, f'df-world-map-zoom-{version}', source)
    write_zip(binary_zip, 'WorldMapZoom', files)
    with checksum.open('x', encoding='utf-8', newline='\n') as stream:
        for path in (binary_zip, source_zip):
            stream.write(f'{sha(path.read_bytes())}  {path.name}\n')
    print(f'Prepared {version} from {revision}. Nothing was published.')
    print(binary_zip)
    print(source_zip)
    print(checksum)


if __name__ == '__main__':
    main()
