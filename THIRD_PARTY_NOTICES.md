# Third-party notices

World Map Zoom's original code and documentation use the [Zlib license](LICENSE).
Contributions are accepted under that same license. Forks and extensions are welcome.

The native plugin compiles against DFHack headers and its `DFHackVersion.cpp`
from the exact revision in [compatibility.json](compatibility.json). DFHack's
core, plugins, and scripts use Zlib unless otherwise noted. The upstream
license collection is preserved verbatim in [licenses/DFHack.rst](licenses/DFHack.rst).
The upstream sources remain at [DFHack](https://github.com/DFHack/dfhack) and
[df-structures](https://github.com/DFHack/df-structures). This is an independent
DFHack plugin, not an official DFHack or Bay 12 release.

Dwarf Fortress, its graphics, and the game content visible in screenshots belong
to their respective owners. The mod's license does not relicense those assets.
Screenshots document the mod running in the game. No game executable, game
assets, saves, DFHack runtime, Lua runtime, SDL runtime, or compiler is included.
Users provide their own compatible game and DFHack installation.

SDL2 is used through the installed game's API; Lua through installed DFHack.
Their runtime licenses remain with their upstream distributions. Python image
validation optionally uses Pillow and NumPy, which are not bundled.
