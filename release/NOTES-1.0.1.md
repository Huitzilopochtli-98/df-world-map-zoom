# World Map Zoom 1.0.1

This update restores zoom on **Windows 64-bit with Steam Dwarf Fortress 53.17
and DFHack 53.17-r1**.

1. Close Dwarf Fortress.
2. Download **WorldMapZoom-1.0.1-windows-x64.zip** from the assets below.
3. Right-click the ZIP, choose **Extract All**, and open the **WorldMapZoom** folder.
4. Type `powershell` in File Explorer's address bar, press Enter, and run:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
   ```

5. Restart Dwarf Fortress with DFHack. Open the fortress or embark world map,
   press **Ctrl + Shift + D**, and run `gui/worldmap-zoom`.

Run the installer over an existing installation to upgrade. If you are still
on Dwarf Fortress 53.16 and DFHack 53.16-r3, use
[World Map Zoom 1.0.0](https://github.com/Huitzilopochtli-98/df-world-map-zoom/releases/tag/v1.0.0).
