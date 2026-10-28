# World Map Zoom 1.0

The first 1.0 stable release of World Map Zoom. Zoom your world map to **2x or 4x**,
drag to move around, and hover over places to inspect them. Text and buttons
stay their normal size.

## Download and install

Download **WorldMapZoom-1.0.0-windows-x64.zip** from the assets below.
Close Dwarf Fortress, right-click the ZIP and choose **Extract All**, then
open the extracted **WorldMapZoom** folder.

Click File Explorer's address bar, type `powershell`, and press Enter. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

Start the game and open the fortress world map or embark world map.
Press **Ctrl + Shift + D**, type `gui/worldmap-zoom`, and press Enter.
The mod opens at 2x. Scroll to zoom, drag to move, and press Esc to close.

**Requires Windows 64-bit, Steam Dwarf Fortress 53.16, and DFHack 53.16-r3.**
The installer checks the exact supported builds. Other versions need a compatible build.
Source-only downloads require compiling the plugin before installation.

## What changed

- Rewritten README with step-by-step installation, in-game startup, controls,
  updating, removal, and troubleshooting.
- Promoted the tested 0.3.0 implementation to **1.0.0**.
- Updated package version metadata and release files.
- Fixed installation with Windows' built-in PowerShell 5.1.

The native DLL and runtime scripts are unchanged from 0.3.0. This promotion adds
no new zoom behavior and does not broaden game or DFHack compatibility.
If you already use 0.3.0, the zoom features are the same. You can install 1.0.0
over it using the steps above, with the game closed.

The Windows ZIP includes source, validation evidence, and a `PROVENANCE.json`
linking the tested DLL to the exact public source commit. `SHA256SUMS.txt`
verifies the downloads. See the README for full instructions and known limits.

Open source under the Zlib license. Forks and extensions are welcome.
