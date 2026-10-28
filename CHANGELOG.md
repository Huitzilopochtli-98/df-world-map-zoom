# Changelog

## 1.0.0 - stable release

- Promoted the tested 0.3.0 implementation to version 1.0.0.
- Rewrote the README for first-time users, with direct download links and
  step-by-step installation, startup, controls, updating, and removal.
- Added troubleshooting for common installation and startup problems.
- Fixed installer payload validation on Windows PowerShell 5.1 so the
  documented commands work with Windows' built-in PowerShell.
- Updated the package version, release profile, and publishing instructions.

The native DLL, runtime scripts, and supported DF/DFHack builds are unchanged
from 0.3.0. Existing native validation remains applicable; this release does
not introduce new rendering or gameplay behavior. Installer JSON array handling
is corrected for Windows PowerShell 5.1 as well as PowerShell 7.

## 0.3.0 — first public package

- Native world-map magnification at 1x, 2x, and 4x for high-level embark and
  the normal fortress world map, with native interface text at its original size.
- Pointer-anchored zoom, left/middle drag panning, inverse-mapped hover, and
  optional native selection with drag/click separation.
- Positive-viewport SDL target-texture composition fixes the black map observed
  with the earlier negative-viewport implementation on Direct3D.
- Installer compatibility checks, conflict backups, and conservative uninstall.
- Public source, Zlib licensing, sanitized validation records, standalone CI,
  source build instructions, and release packaging with SHA-256 checksums.
- Public installer rejects incomplete source downloads before writing files and
  can uninstall using its known payload even without a local compiled DLL.

The native plugin and map scripts are the tested 0.3.0 implementation. Public
preparation changes packaging, documentation, line endings, and build tooling.
Earlier 0.1.0–0.2.1 packages were development builds and are not published here.
