# Publishing the prepared release

The local repository is prepared for `Huitzilopochtli-98/df-world-map-zoom`.
No remote repository, push, or public release is created by local preparation.
The prepared checkout has a `main` commit and an annotated `v0.3.0` tag.

Publish this directory only. The parent workspace contains private diagnostics,
game copies, saves, and build tools and must not be uploaded. This repository
includes original source, documentation, screenshots, and sanitized evidence.
Compiled artifacts stay out of Git history and are distributed as release assets.

## First publication

After authorizing publication, use an authenticated GitHub CLI in this repository
or perform the equivalent steps through GitHub's interface. The prepared name
and account below can be changed before creating the remote.

```powershell
gh auth status
gh repo create Huitzilopochtli-98/df-world-map-zoom --public --source=. --remote=origin --push --description "Native world map zoom for Dwarf Fortress and DFHack: 1x, 2x, 4x"
git push origin v0.3.0
```

Wait for the standalone workflow on `main` to pass. It has not run on GitHub
during local preparation. Check the two prepared release ZIPs against their
adjacent `SHA256SUMS.txt`. Put all three in `dist/` if using these commands:

```powershell
gh release create v0.3.0 dist/WorldMapZoom-0.3.0-windows-x64.zip dist/df-world-map-zoom-0.3.0-source.zip dist/SHA256SUMS.txt --verify-tag --draft --title "World Map Zoom 0.3.0" --notes-file release/NOTES-0.3.0.md
```

Review the draft's tag, filenames, checksums, compatibility wording, and preview
images. Publish the draft from GitHub's release page when ready. There is no
workflow that automatically publishes a release. GitHub's own **Source code**
downloads omit the compiled DLL, so the Windows asset must remain prominently
identified in release notes. Add topics such as `dwarf-fortress`, `dfhack`, `lua`,
and `mod` in the repository settings if useful.

## Regenerating assets or making a later release

From a clean committed source checkout, supply the validated DLL explicitly:

```powershell
python tools/package_release.py --native-dll "PATH/TO/VALIDATED/worldmap-zoom-render.plug.dll" --output dist
```

For 0.3.0 this must be the exact DLL already recorded in `release/0.3.0.json`.
The supplied release ZIP contains it. The script rejects a different DLL and
refuses to overwrite existing assets. It packages `git archive HEAD`, binds the
native hash to that public source commit in `PROVENANCE.json`, writes internal
and external checksums, and includes no `.git` metadata or ignored build files.

For a new native build, perform game validation, update `compatibility.json`,
the release profile, evidence, changelog, and release notes, then commit and tag
that source before packaging. The packager checks the recorded hash; it cannot
establish that a new binary behaves correctly. Do not mark a rebuild as the
previously tested DLL. Python ZIP creation is deterministic for the same input
and compression implementation; cross-toolchain native reproducibility is not
claimed.

The local commit uses the connected GitHub account's `users.noreply.github.com`
identity instead of a personal email. No authentication credential is stored
in the repository. Source ZIPs have no Git history; keep the prepared local Git
checkout when publishing the existing tag.

Reference: [GitHub CLI repository creation](https://cli.github.com/manual/gh_repo_create),
[release creation](https://cli.github.com/manual/gh_release_create), and
[GitHub releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
