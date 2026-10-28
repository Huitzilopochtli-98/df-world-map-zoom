# World Map Zoom - Workshop setup companion

**Manual installation is required. Subscribing alone does not enable zoom.**

World Map Zoom magnifies the fortress world map and high-level embark map to
2x or 4x while keeping interface text and buttons at their normal size.

This Workshop item contains installation help. The actual zoom feature needs
a native DFHack plugin installed using the Windows release package.

## Install the zoom feature

1. Download **WorldMapZoom-1.0.0-windows-x64.zip** from the
   [1.0.0 release](https://github.com/Huitzilopochtli-98/df-world-map-zoom/releases/tag/v1.0.0).
2. Close Dwarf Fortress, then right-click the ZIP and choose **Extract All**.
3. Open the extracted **WorldMapZoom** folder. Click File Explorer's address bar,
   type `powershell`, and press Enter.
4. Run:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
   ```

5. Restart the game. Open the fortress world map or embark world map.
6. Press **Ctrl + Shift + D**, enter `gui/worldmap-zoom`, and press Enter.

Requires **Windows 64-bit**, **Steam DF 53.16**, and **DFHack 53.16-r3**.
The installer checks the exact supported game and DFHack files.

## Get these instructions in game

With this companion installed and DFHack running, press **Ctrl + Shift + D**
and run `worldmap-zoom-setup`. You do not need to enable the companion when
creating a world. DFHack discovers its `scripts_modinstalled` help command.

## Remove it

Unsubscribing removes the Workshop companion through Steam. The manually
installed native plugin has a separate uninstaller. Close the game and run
this from the extracted Windows release folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -Uninstall
```

See the [main README](https://github.com/Huitzilopochtli-98/df-world-map-zoom#readme)
for controls, troubleshooting, updating, and known limits.

Original code is under the Zlib license. Game graphics belong to their owners.
The preview is an actual screenshot of the separately installed zoom feature.
