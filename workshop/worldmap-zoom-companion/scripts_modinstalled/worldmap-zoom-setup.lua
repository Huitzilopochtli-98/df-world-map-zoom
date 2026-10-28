-- Installation help for World Map Zoom; the native plugin needs manual setup.
local args = {...}
if #args > 1 or (#args == 1 and args[1] ~= '--help') then
    error('Usage: worldmap-zoom-setup [--help]')
end

print([[
World Map Zoom 1.0 - manual installation required

This Workshop companion adds this help command, not the native zoom plugin.
Subscribing alone does not enable zoom.

Requires Windows 64-bit, Steam DF 53.16, and DFHack 53.16-r3.

1. Download WorldMapZoom-1.0.0-windows-x64.zip from:
   https://github.com/Huitzilopochtli-98/df-world-map-zoom/releases/tag/v1.0.0
2. Close Dwarf Fortress completely.
3. Right-click the ZIP, choose Extract All, and open WorldMapZoom.
4. In File Explorer's address bar, type powershell and press Enter.
5. Run:
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
6. Restart the game. Open the fortress world map or embark world map.
7. Press Ctrl+Shift+D, type gui/worldmap-zoom, and press Enter.

Scroll to zoom; left/middle drag to move; Esc closes the zoom tool.
Keep the extracted folder for updating or uninstalling.

Full instructions and source:
https://github.com/Huitzilopochtli-98/df-world-map-zoom

This help command does not install files, open a browser, or change game data.
]])
