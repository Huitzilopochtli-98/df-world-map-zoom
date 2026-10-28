# Implementation and rebuilding

The renderer plugin interposes `renderer_2d_base::update_full_map_port` and `update_map_port_tile` using DFHack's supported VTableInterpose API. At 2x and 4x it calls the original map drawing code into an SDL target texture, then copies the camera crop into the map rectangle at the selected magnification. All viewports remain nonnegative. Native terrain, site layers, texture choices, and their order are preserved; the mod does not reconstruct geography. A thread-local guard prevents nested map callbacks from applying the operation twice.

Rendering changes SDL drawing state only on the graphics thread. It does not rewrite native texture arrays, renderer origins, or game geography. `worldmap-zoom-canvas.h` owns one target texture and checks restoration of the previous target, scale, viewport, clip, and draw color. Consecutive individual map-tile updates share a target pass; native UI drawing boundaries and presentation finish that pass before any interface draws. A visible-tile coverage map avoids a redundant full draw on camera changes, while an incomplete crop is filled through the original full-map renderer before composition.

The canvas is released before native resize, grid resize, fullscreen, and video reinitialization. SDL renderer/window identity and dimensions are checked before reuse. Textures belonging to an already replaced renderer are forgotten without dereferencing them, because SDL destroys that renderer's textures. SDL target/device reset events invalidate the cache; disable, world unload, and logical plugin unload queue graphics-thread cleanup. Camera changes request native redraws and invalidate canvas coverage.

Version 0.2.0 used a translated viewport with a negative origin. SDL's `direct3d` backend silently produced a black map for that state, even though its setters and restoration checks succeeded. A native desktop reproduction and a six-backend SDL probe isolated that failure: the same operation worked on the other tested backends. Version 0.2.1 replaces the operation with target-texture composition and adds a displayed-window regression test. Earlier internal/software captures did not establish desktop Direct3D correctness.

Runtime DF and DFHack/structure commits are checked before mapped renderer fields are read or hooks are installed. Hook installation/removal is queued with `runOnRenderThread`. On Windows, the module is pinned until process exit to close the queued-callback and fetched-vtable-call races during physical unload. Logical unload disables scaling immediately and detaches hooks on the graphics thread.

The Lua camera uses continuous world-edge coordinates and converts to the native integral camera plus a crop offset. High-level panning uses the same `region_cent_x/y` update path as the matching release's `edgescroll` plugin. Native selection pointers, embark dimensions, squads, and orders are never assigned by the mod.

Wheel and Z zoom use the world coordinate at the map pointer to solve the new camera center before applying world bounds. The shared camera defines the 1x/2x/4x steps and cycling limits. Toolbar zoom falls back to the center. Native 1x rendering requires an integral tile camera; it rounds by at most half a tile per axis. At magnified scales the native camera remains integral while the source crop supplies the fractional camera offset, rounded to a source pixel. At 4x the crop uses one quarter of the native width/height; the target texture allocation remains the same size as at 2x.

`worldmap-zoom.gesture` captures the press position, camera, zoom, and viewport. A six-pixel threshold separates a pending left click from a drag. Panning derives from total displacement from the press, avoiding accumulation of rounding error. Once crossed, the threshold remains crossed even when the pointer returns. Release forwards one short left click only if selection is enabled and the release remains on the map. Middle gestures never select. Resize, screen change, invalid tracking, and dismissal cancel capture. Held buttons are masked during all native parent logic/render calls.

An SDL event watcher tracks input focus and increments a generation on every focus loss. A gesture stores that generation, so loss followed by regain between Lua frames still cancels it. The callback touches only atomics and the cached SDL window ID; it does not inspect mapped game data. Watch installation/removal runs on the graphics thread, and the module remains pinned. SDL documents that event watchers may run on other threads and also receive pushed test events. See [SDL_AddEventWatch](https://wiki.libsdl.org/SDL2/SDL_AddEventWatch).

Input follows the inverse of the rendered transform. Before a forwarded click, native logic/render refresh hover at the transformed pointer. The press then goes through native feed/logic, with transitions checked before processing another phase. Press flags are consumed to prevent a second action after the tool closes. Native UI occupancy is captured before drawing the Lua controls, with a neutral pointer so hover text is not mistaken for an interactive control. It refreshes after UI actions and window changes.

The high-level embark `Biome` mode and fortress `NORMAL` mode are the supported contexts. Entering another geographic or action mode restores native rendering. Native selection is opt-in; inspection is the default.

The direct Windows build requires Python 3.10+, Git, MSVC 14.44 with a Windows SDK, and the pinned DFHack source with generated headers. Install the Visual Studio C++ tools for x64/x86 and the v14.44 toolset, then initialize an x64 developer command prompt with `VsDevCmd.bat -arch=x64 -host_arch=x64 -vcvars_ver=14.44`. Use the `VsDevCmd.bat` from your Visual Studio/Build Tools installation. Keep using that shell so its compiler, INCLUDE, and LIB environment stays available. The build creates import libraries from the tested DFHack/Lua DLL exports and compiles a Release `/MD /vmg /vmm` plugin. It does not rebuild or replace DFHack itself.

```powershell
git clone --depth 1 --branch 53.16-r3 https://github.com/DFHack/dfhack.git dfhack
git -C dfhack submodule update --init --depth 1 library/xml
perl dfhack/library/xml/codegen.pl dfhack/library/xml dfhack/library/include/df
python tools/build_windows.py --dfhack-source dfhack --hack-path "PATH/TO/DFHACK/hack"
```

Perl needs `XML::LibXML` and `XML::LibXSLT`. For a portable toolchain instead of a developer shell, append `--msvc-root "PATH/TO/PORTABLE/MSVC"`; that root must contain `VC/Tools/MSVC` and `Windows Kits/10`. The tested toolchain is MSVC 14.44.35207 and Windows SDK 10.0.26100.0. Both toolchain-selection paths were checked locally, using the same portable compiler and SDK; a separate Visual Studio installation was not tested. Build intermediates go to ignored `work/worldmap-zoom-build`, or `--build-dir`. The output is `hack/plugins/worldmap-zoom-render.plug.dll`. This source is Windows-specific.

The builder refuses mismatched DFHack and structure commits or DFHack DLL hashes.
It reads import names from your installed `dfhack.dll` and `lua53.dll`; those
files are inputs you supply and are not redistributed here. Match the game too
before installation. An updated game or DFHack needs new ABI validation, not
just a version-string change. The released DLL is the original in-game-tested
0.3.0 binary, recorded in `release/0.3.0.json`. A rebuilt DLL can have different
PE timestamps and paths; byte-for-byte reproducibility is not claimed. Locally
rechecking the public source build did not replace native gameplay acceptance
of the original released DLL.

Run the standalone suite from the root with `lua tests/run.lua` (Lua 5.3+) and
`python -m unittest discover -s tests -p "test_*.py"`. The GitHub workflow uses
Lua 5.3 and Python on Ubuntu. It does not build or execute the native Windows
plugin. Its success establishes standalone checks, not game compatibility.

`tests/test_camera.lua` and `tests/test_gestures.lua` are pure Lua and require this package's Lua module directory on `package.path`. `tests/test_input.lua` covers inverse pixel mapping and exception-safe pointer/input restoration. `tests/native_gestures.lua` runs against an open magnifier in a disposable game and synthesizes DFHack pointer/button input. Its asynchronous focus test posts loss and regain through SDL, testing the native event watcher and GUI cancellation together. `tests/test_installer.ps1` exercises installation against copied executables in a new disposable directory. Native acceptance results and their limits are in `VALIDATION.md`.

For the installer suite, supply `-GameExe "PATH/TO/Dwarf Fortress.exe"`,
`-DfhackDll "PATH/TO/hack/dfhack.dll"`, and `-TestRoot "NEW/EMPTY/PATH"` to
`tests/test_installer.ps1`. Build the plugin first, or run the suite from an
extracted Windows release ZIP. This test copies only the required executable
inputs into its test directory. It checks missing-payload rejection and
uninstall from source without a local DLL as well as backups and recovery.

Relevant matched sources:

- [DFHack 53.16-r3](https://github.com/DFHack/dfhack/tree/0bf381cc1615656acf756e6e67573fffca715125)
- [Pinned structure definitions](https://github.com/DFHack/df-structures/tree/d8ff8a6326db37c11dc4173fadcf30b56e51b42d)
- [Graphics-thread callback implementation](https://github.com/DFHack/dfhack/blob/53.16-r3/library/modules/DFSDL.cpp)
- [Matched edgescroll camera path](https://github.com/DFHack/dfhack/blob/53.16-r3/plugins/edgescroll.cpp)
- [Published graphics source used as background evidence](https://github.com/Putnam3145/Dwarf-Fortress--libgraphics--)

The background graphics source is not substituted for installed-build evidence. The runtime probe, pixel comparisons, and native interaction tests bind this implementation to the installed binaries. DFHack's license is retained in `licenses/DFHack.rst`.
