# Validation — 0.3.0

Validated October 27, 2026 against the installed Windows Steam DF 53.16 / DFHack 53.16-r3 binaries and the normal desktop `direct3d` backend. Exact commits and executable hashes are in `compatibility.json`. Tests use explicitly selected **Portable Folder: region2** and **Portable Folder: region4** copies; original saves are not write targets. The native test worlds are 129×129 tiles.

## New scale and controls

The camera, native renderer, and controls accept exactly 1x, 2x, and 4x. Wheel and +/− step through these levels with endpoint clamps. Z cycles 1x → 2x → 4x → 1x; R restores the initial camera at 1x. Default activation remains 2x. The existing positive-viewport texture composition is retained; 4x crops one quarter of the native map dimensions without increasing the target texture allocation.

Actual toolbar clicks reach 4x. Native tests verify wheel steps, both endpoint clamps, the full Z cycle, and pointer anchoring for 1x→2x and 2x→4x. Unit tests independently verify every pair of scale transitions, including 4x→2x and 4x→1x, world bounds, and the native 1x half-tile rounding limit. Unsupported 8x is rejected by the native API.

## Native 4x rendering

| Measurement | Fortress 2560×1440 fullscreen | Embark 1000×700 window |
| --- | ---: | ---: |
| Compared map pixels | 3,321,822 | 572,972 |
| Expected 4x composition match | 99.9989% | 99.7989% |
| Native UI exact match | 100% | 100% |
| Reset exact match | 100% | 100% |
| Added complete-frame p95 | -1.771 ms | -0.247 ms |
| Zoom-to-presentation response | 47–78 ms | 15–47 ms |

Median channel error is zero in both contexts. The oracle compares a same-camera 1x reference to the expected nearest-neighbor crop/enlargement, excluding native UI and tool controls at both source and destination. Reset is separately compared to the original camera; repeated scale changes are included. Actual displayed-window captures independently verify visible 4x terrain in both contexts. A displayed 2x regression capture also passes, preserving the Direct3D black-map fix.

Each scale has 256 map-hook samples and 256 complete renderer-frame samples. Complete frames include interface drawing and presentation. Target switching submits queued GPU work inside the map hook, so map-hook timing alone charges different work at native 1x; both distributions remain in the raw records. Complete-frame p95 meets the provisional 2 ms added-time target. Negative differences are observations, not a general speedup claim. Response checks follow the requested camera generation through presentation and remain under 100 ms; they do not measure physical monitor latency.

## Input and lifecycle

**586 native gesture checks** pass across fullscreen fortress, 1200×800 embark, and resized 1000×700 embark contexts. These include left/middle dragging at all three scales, drag/click separation, a drag returning to its start, release outside, focus loss/regain between Lua updates, and Exit/disable/unload with a pending 4x press. Reload succeeds. Native tests synthesize input through DFHack and post focus events through SDL; they are not physical mouse or Alt-Tab observations.

At 4x, native selection identifies fortress site 285 and embark position (408,1000). No orders or embark are issued; the 4×4 embark footprint is unchanged. The native camera is centered on each known target before selection so it remains visible at the narrower 4x field of view. No selection/site pointer is assigned by the mod or test.

A real native window resize during a 4x press cancels capture, recreates the canvas, and synchronizes the camera from a 75×50 to a 63×44 map port. Subsequent displayed/pixel checks pass with zero SDL restoration errors. Hardware device loss was not forcibly induced.

The 4x target-texture sequence also passes a hidden synthetic probe on direct3d, direct3d11, direct3d12, opengl, opengles2, and software. This is graphics-operation coverage on six backends; full native-game acceptance uses Direct3D. The probe retains the legacy negative-viewport case to demonstrate why the former mechanism failed on Direct3D.

## Automated and package checks

- 6,930 camera checks across 17/33/65/129/257 tile worlds and odd/even viewport sizes.
- 319 inverse-input and exception-restoration checks at 1x, 2x, and 4x.
- 307 pointer-anchor, zoom-step/cycle, and drag lifecycle checks.
- Seven diagnostic mock checks; native binding is separately established by runtime reports and installed executable checksums.
- Installer backup, idempotence, rollback, modified-file preservation, recovery record, checksum rejection, and WhatIf pass with all eight assets.
- The pinned-source Windows builder compiled the native DLL; source, build log, checksums, and native evidence are included.

Current native records are under `evidence/v0.3.0/`; local path redactions are documented in `evidence/README.md`. Earlier development archives are not part of the public release. Publication tooling and installer checks are recorded separately under `evidence/publication/`. Run `tests/native_rendering.py` with `--zoom 4` to repeat composition/timing coverage, and `tests/presented_map.py` with `--expected-zoom 4` in a normal desktop session to check the displayed game window. `tests/sdl_backend_regression.py --sdl-dll "PATH/TO/GAME/SDL2.dll" --zoom 4` repeats the six-backend operation test and requires Direct3D to be available. Python image tests require Pillow and numpy.

Native coverage uses sampled locations and copied worlds, not every site cluster or gameplay state. Magnified crops retain source-pixel rounding; 1x retains native tile-camera rounding, and world bounds can force anchor clamps. Other magnifications, preference persistence, unsupported geographic/action modes, and other game/DFHack builds remain outside this release.
