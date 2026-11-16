# Local build for DF 53.17 / DFHack 53.17-r1

This is a modified local fork of World Map Zoom 1.0.0, prepared November 16,
2026. It is not a release from the original author. The compatibility profile
is pinned to the exact Steam Windows executables in `compatibility.json`.

The native renderer was rebuilt with MSVC 14.44 against DFHack commit
`3bc63a220af608e1cf20b123dc45bc0a22e296ab` and structures commit
`611369f12c5f214e0f8114900398ba74e8a2dd2f`. Comparing the old and new
definitions found no changes to the graphics, renderer, map-port, or map-screen
layouts used by this mod. DFHack's generated type identities changed, and this
build uses the newly generated headers and the installed DLL's exports.
Both Lua and native compatibility checks remain strict.

## Automatic startup

The startup fragment `dfhack-config/init/dfhack.worldmap-zoom.init` enables
`worldmap-zoom-autostart`. The zoom tool opens at 2x when a supported fortress
world map or high-level embark map becomes ready. Leaving a detailed embark
view or site-action panel also starts a new supported map visit.

Esc closes the zoom tool for the current visit. It stays closed until you leave
and return to a supported map. `gui/worldmap-zoom` still opens it manually.
Run `disable worldmap-zoom-autostart` to stop automatic launching for the
session. Remove the startup fragment to disable it for future game starts.

## Installation and removal

Close Dwarf Fortress first. The binary ZIP contains all required files. On
Linux with the Windows Steam/Proton build, run from the extracted package:

```sh
python3 Install-linux.py --game-path '/path/to/steamapps/common/Dwarf Fortress' --hack-path '/path/to/steamapps/common/DFHack/hack'
```

For removal, repeat that command with `--uninstall`. The installer checks the
exact executable hashes, backs up conflicting mod files, verifies every copied
file, and writes `dfhack-config/worldmap-zoom-install.json`. Removal restores
the original files and preserves subsequent user edits. Failed installations
restore the files they changed. Saves are not installation targets.

On Windows, the included `Install.ps1` also has the updated compatibility and
payload profiles. The Linux installer was tested locally; the updated
PowerShell installer was not executed during this port.

## Validation

- The user confirmed that the rebuilt mod works in the isolated copied game.
- All 6,930 camera, 319 input-restoration, 307 gesture, and seven diagnostic
  mock checks pass.
- Additional autostart mocks cover native map readiness, both map types,
  one launch per visit, Esc suppression, submode transitions, world unload,
  duplicate events, disable, and renderer launch failure.
- All 12 Python tests pass, including installation backup/restore, idempotence,
  modified-file preservation, executable/payload rejection, and failure recovery.
- The normal Steam game was reopened after installation. A live read-only check
  confirmed DF 53.17, DFHack 53.17-r1, the normal configuration directory,
  and the enabled startup hook. The user is checking actual map behavior.

These checks do not repeat the upstream pixel-comparison and performance
acceptance suite. Original upstream evidence remains historical. Local records
are in `evidence/local-53.17`; the new DLL hash is recorded in
`release/1.0.0-local.53.17.json`.

## Rebuilding

Generate headers using the pinned DFHack tree's `library/xml/codegen.pl`, then
run `tools/build_windows.py` with the matching source, installed DFHack DLLs,
and MSVC 14.44 toolchain. On Linux, add `--wine --msvc-root /path/to/msvc` and
set `WINEPREFIX` to a dedicated compiler prefix. Build/version metadata now
comes from `compatibility.json`. Native rendering code is otherwise unchanged.
