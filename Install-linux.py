#!/usr/bin/env python3
"""Install this local Windows build in a Linux Steam/Proton installation."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import shutil
import uuid

PACKAGE = Path(__file__).resolve().parent
ALLOWED = {
    'dfhack-config/scripts/gui/worldmap-zoom.lua',
    'dfhack-config/scripts/worldmap-zoom.lua',
    'dfhack-config/scripts/worldmap-zoom-autostart.lua',
    'dfhack-config/init/dfhack.worldmap-zoom.init',
    'hack/lua/plugins/worldmap-zoom-render.lua',
    'hack/lua/worldmap-zoom/camera.lua',
    'hack/lua/worldmap-zoom/context.lua',
    'hack/lua/worldmap-zoom/gesture.lua',
    'hack/lua/worldmap-zoom/input.lua',
    'hack/plugins/worldmap-zoom-render.plug.dll',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-path', type=Path, required=True)
    parser.add_argument('--hack-path', type=Path, required=True)
    parser.add_argument('--uninstall', action='store_true')
    args = parser.parse_args()
    game, hack = args.game_path.resolve(), args.hack_path.resolve()
    config = game/'dfhack-config'
    record = config/'worldmap-zoom-install.json'
    backups = config/'worldmap-zoom-backups'
    steam = game.parents[2]

    def windows(path):
        path = path.resolve()
        if (steam/'steamapps').is_dir() and path.is_relative_to(steam):
            return 'S:\\' + str(path.relative_to(steam)).replace('/', '\\')
        return 'Z:' + str(path).replace('/', '\\')

    def linux(path):
        if path.startswith('S:\\'):
            return steam/path[3:].replace('\\', '/')
        if path.startswith('Z:\\'):
            return Path(path[2:].replace('\\', '/'))
        raise ValueError('Unknown backup drive')

    def destination(relative):
        if relative not in ALLOWED:
            raise ValueError('Unknown payload path: '+relative)
        root, name = (hack, relative[5:]) if relative.startswith('hack/') else (config, relative[14:])
        target = (root/name).resolve()
        if not target.is_relative_to(root):
            raise ValueError('Payload would leave its destination')
        return target

    for process in Path('/proc').iterdir():
        try:
            if (process/'comm').read_text().startswith('Dwarf Fortress'):
                raise RuntimeError('Close Dwarf Fortress before installing or removing the mod')
        except (FileNotFoundError, ProcessLookupError, PermissionError, NotADirectoryError):
            pass
    payload = json.loads((PACKAGE/'payload.json').read_text())
    if len(payload) != len(ALLOWED) or set(payload) != ALLOWED:
        raise ValueError('Invalid payload manifest')
    prior = json.loads(record.read_text(encoding='utf-8-sig')) if record.exists() else None

    if args.uninstall:
        pending = []
        for entry in (prior or {}).get('files', []):
            target = destination(entry['relative'])
            if entry['preserve']:
                continue
            if target.exists() and sha(target) != entry['sha256'].upper():
                pending.append(entry)
                print('Preserved modified file:', target)
                continue
            backup = linux(entry['backup']).resolve() if entry.get('backup') else None
            if backup and not backup.is_relative_to(backups.resolve()):
                raise ValueError('Invalid backup path')
            if backup and not backup.is_file():
                raise ValueError('Missing original backup: '+str(backup))
            if target.exists():
                target.unlink()
            if backup:
                shutil.copy2(backup, target)
        if pending:
            prior['files'] = pending
            record.write_text(json.dumps(prior, indent=2)+'\n')
        else:
            record.unlink(missing_ok=True)
        print('World Map Zoom removed; backups retained.')
        return

    compat = json.loads((PACKAGE/'compatibility.json').read_text())
    for path, expected in [(game/'Dwarf Fortress.exe', compat['gameSha256']),
                           (hack/'dfhack.dll', compat['dfhackSha256'])]:
        if sha(path) != expected.upper():
            raise ValueError('Unsupported game or DFHack executable: '+str(path))
    for relative in payload:
        if not (PACKAGE/relative).is_file():
            raise ValueError('Incomplete package: '+relative)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:8]
    old_entries = {entry['relative']: entry for entry in (prior or {}).get('files', [])}
    entries, rollback = [], {}
    old_record = record.read_bytes() if record.exists() else None
    try:
        for relative in payload:
            source, target = PACKAGE/relative, destination(relative)
            digest, existing = sha(source), sha(target) if target.exists() else None
            entry = dict(relative=relative, sha256=digest, backup=None, preserve=False)
            old = old_entries.get(relative)
            if existing and old and existing == old['sha256'].upper():
                entry.update(backup=old['backup'], preserve=bool(old['preserve']))
            elif existing == digest:
                entry['preserve'] = True
            elif existing:
                backup = backups/stamp/relative
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(target, backup)
                entry['backup'] = windows(backup)
            entries.append(entry)
            if existing != digest:
                rollback[target] = target.read_bytes() if target.exists() else None
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
            if sha(target) != digest:
                raise RuntimeError('Installed checksum mismatch: '+str(target))
        data = dict(version=compat['modVersion'], complete=True, gamePath=windows(game),
                    hackPath=windows(hack), configPath=windows(config), files=entries)
        record.parent.mkdir(parents=True, exist_ok=True)
        record.write_text(json.dumps(data, indent=2)+'\n')
    except Exception:
        for target, original in rollback.items():
            if original is None:
                target.unlink(missing_ok=True)
            else:
                target.write_bytes(original)
        if old_record is None:
            record.unlink(missing_ok=True)
        else:
            record.write_bytes(old_record)
        raise
    print(f'Installed World Map Zoom {compat["modVersion"]}; verified {len(entries)} files.')
    print('Automatic startup is enabled for supported world maps.')


if __name__ == '__main__':
    main()
