# Contributing

Forks, fixes, and extensions are welcome under the [Zlib license](LICENSE).
By submitting changes, you agree to license your contribution under those terms.
Keep existing copyright and third-party notices. Mark modified forks clearly.

Run `lua tests/run.lua` from the root with Lua 5.3 or newer. Python tooling needs
Python 3.10 or newer. Run `python -m unittest discover -s tests -p "test_*.py"`.
The GitHub workflow runs these standalone checks; it does not run Dwarf Fortress
or certify native rendering. Native changes require a matched Windows build and
the in-game checks described in [TECHNICAL.md](TECHNICAL.md) and
[VALIDATION.md](VALIDATION.md). Use disposable copies of saves for testing.

Include the DF/DFHack versions, affected map context, reproduction steps, and
relevant checks in an issue or pull request. If sharing diagnostic output,
remove personal directory names first. Do not upload saves or game binaries.
Use small focused changes and explain behavior and validation. Do not loosen
compatibility checks to accommodate a new release without rebuilding and testing.

Native rendering, Lua input mapping, and installer compatibility must stay in
agreement. Draw only on the graphics thread; use native map data and selection
paths. See the technical notes before changing those boundaries.
