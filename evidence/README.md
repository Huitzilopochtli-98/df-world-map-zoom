# Validation evidence

These records were collected on October 27, 2026 for the tested 0.3.0 native
plugin. [VALIDATION.md](../VALIDATION.md) explains the measurements and limits.
The installer and build log here describe the pre-publication package.
Publication preparation adds a stricter payload check and developer-shell build
support; its separate checks are in `publication/`.

For public sharing, absolute validation-workspace paths were replaced with
`<validation-workspace>`, and the installed game directory with `<game-directory>`.
Line endings and trailing blank lines were normalized in text records. No
measurement, result flag, executable hash, or screenshot pixel was changed.
Screenshots contain no added metadata. The private workspace, saves, original
game binaries, and toolchain are excluded. These are historical observations,
not a guarantee for different game or DFHack builds.

The original deployment record hashes the pre-publication script files.
Public source uses LF line endings; current release hashes are generated from
the public package and are recorded separately in its `SHA256SUMS.txt`.
