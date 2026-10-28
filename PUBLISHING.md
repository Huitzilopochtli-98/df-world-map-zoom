# Publishing a release

The public repository is
[Huitzilopochtli-98/df-world-map-zoom](https://github.com/Huitzilopochtli-98/df-world-map-zoom).
Source is tracked in Git; compiled downloads are GitHub release assets.

Publish this repository only. Its parent workspace contains private test data
and development tools. Do not upload game files, saves, or compiler binaries.

## Prepare the source and package

1. Update the README, changelog, `compatibility.json`, release notes, and
   `release/<version>.json`. For a new native build, collect game validation
   and record that DLL's hash. Keep historical evidence labeled accurately.
2. Run the relevant checks, commit the source, and create an annotated tag.
3. From a clean checkout, create the release assets:

   ```powershell
   python tools/package_release.py --native-dll "PATH/TO/VALIDATED/worldmap-zoom-render.plug.dll" --output dist
   ```

For **1.0.0**, use the exact tested DLL recorded in `release/1.0.0.json`.
It is the same binary distributed with 0.3.0. The packager checks that hash,
packages `git archive HEAD`, and writes `PROVENANCE.json` and checksums.
It refuses a different DLL or existing output files. It does not build, install,
push, or publish anything.

The Windows ZIP contains the native DLL plus the public source. The source ZIP
and GitHub's automatic source downloads omit the compiled plugin. Use the
Windows ZIP when linking beginners to an installable download.

## Upload and publish 1.0.0

Verify that `gh api user --jq .login` returns the intended publishing account.
Push the committed source and tag:

```powershell
git push origin main
git push origin v1.0.0
```

Wait for GitHub's standalone checks to pass. Those checks exercise Lua and
Python tooling; they do not run Dwarf Fortress or certify native rendering.

Create a draft release with the generated files:

```powershell
gh release create v1.0.0 dist/WorldMapZoom-1.0.0-windows-x64.zip dist/df-world-map-zoom-1.0.0-source.zip dist/SHA256SUMS.txt --repo Huitzilopochtli-98/df-world-map-zoom --verify-tag --draft --title "World Map Zoom 1.0" --notes-file release/NOTES-1.0.0.md
```

Check the tag's source commit, compatibility wording, asset sizes, and SHA-256
hashes before publishing the draft:

```powershell
gh release edit v1.0.0 --repo Huitzilopochtli-98/df-world-map-zoom --draft=false --latest --verify-tag
```

There is no automatic release publishing workflow. Later releases need their
own version, tag, profile, notes, and validation as appropriate. The packager
checks the recorded DLL hash; it cannot establish correct behavior on its own.
Native builds are not promised to produce identical bytes across toolchains.

Commits use the publishing account's `users.noreply.github.com` identity.
Credentials and Git metadata are not included in release ZIPs.
