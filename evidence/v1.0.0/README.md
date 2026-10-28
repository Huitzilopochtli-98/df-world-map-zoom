# Version 1.0.0 release checks

Checked October 27, 2026. This release promotes the tested 0.3.0 native DLL
and all eight installed payload files without changing their bytes. Game and
DFHack compatibility requirements remain the same. Historical native rendering
and interaction evidence stays under `evidence/v0.3.0/`.

The installer now reads its JSON file list consistently in Windows PowerShell
5.1 and PowerShell 7. Both shells passed the existing installer suite using
copied, matched executable inputs in new disposable directories. The suite
covers installation, conflict backups, repeated installation, removal, modified
file preservation, recovery, executable mismatch rejection, dry runs, missing
payload rejection, and removal using a source-only checkout.

The two installer logs here replace absolute workspace prefixes with
`<validation-workspace>`. No result or executable hash was changed.

The README's default launcher shortcut was checked against the pinned DFHack
53.16-r3 keybindings and quickstart. The standalone Python packaging suite
passed all six tests. No new native game rendering run was claimed for this
documentation, installer, and package metadata release.
