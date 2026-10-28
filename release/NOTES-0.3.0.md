# World Map Zoom 0.3.0

Zoom the native high-level embark map and normal fortress world map to 2x or 4x,
with pointer-anchored zoom, drag panning, mapped hover, and optional native
selection. Native text and interface controls keep their original size.

**Requires Windows x64, Steam Dwarf Fortress 53.16, and DFHack 53.16-r3.**
The installer checks the exact tested executable hashes. Other builds are not
supported by this binary.

Download **WorldMapZoom-0.3.0-windows-x64.zip** for the compiled plugin, installer,
source, and validation records. Extract everything, close Dwarf Fortress, then
run `./Install.ps1` in PowerShell. Open a supported map and run
`gui/worldmap-zoom` in DFHack. See README.md for controls and removal.
GitHub's automatic source archives and the explicit source ZIP need a native
build before installation.

The release includes the original DLL tested in game, unchanged. The package's
`PROVENANCE.json` records its SHA-256 and the exact public source commit.
`SHA256SUMS.txt` alongside the downloads verifies both ZIPs; the Windows ZIP
also contains a file-by-file checksum manifest. Build outputs are not promised
to be byte-identical because PE timestamps and compiler paths can differ.

Open source under Zlib. Forks and extensions are welcome. Game graphics remain
their owners' property. This is an independent mod, not an official DFHack release.

Known limits: only the high-level embark Biome view and fortress NORMAL world
view are magnified; other modes restore native rendering. World bounds can clamp
pointer anchoring; native 1x can snap by half a tile. Close DF before replacing
the DLL. Validation covers sampled locations in copied worlds, not every game
state. See VALIDATION.md for exact measurements and test limits.
