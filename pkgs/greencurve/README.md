# Green Curve package provenance

**Source:** upstream's official x86_64 release binary,
[aufkrawall/green-curve](https://github.com/aufkrawall/green-curve) `0.28`
(released 2026-10-05), `greencurve-0.28-linux-x64.tar.xz`. Its SHA-256
(`071d93de…a3ea43`) matches the release's `.sha256` sidecar and the
`PKGBUILD.bin` pin in upstream commit `baad3e1`. The systemd units, desktop
entry and icon come from `packaging/arch/` at the same tag (commit
`358793a9633c7366d88581dac75942f09cc4f739`), because the tarball ships only the
binary.

A source build is impractical. `build.py` refuses any compiler whose SHA-256
differs from its vendored Zig 0.13.0 manifest, so nixpkgs' Zig can't build it.
The binary links only glibc and `dlopen`s `libnvidia-ml.so.1` and
`libnvidia-api.so.1` by soname. `autoPatchelfHook` sets the Nix glibc loader,
and `autoAddDriverRunpath` adds `/run/opengl-driver/lib` so those libraries
are found. The Linux build has no self-updater.

**Local changes:** none to the binary. The units' `/usr/bin/greencurve` is
rewritten to the store path. Their `[Install]` sections are restated in
`hosts/draba/gpu-tuning.nix`. That module, not upstream's
`--service-install` or `greencurve-setup.sh`, creates the `greencurve` group
and installs the daemon. Don't run either of those on NixOS.

**Build:** `nix build .#greencurve -L --no-link`. Then check that
`greencurve --probe` reports `NVML=yes NvAPI=yes` (as the desktop user, it sees
only the 5060).

**Updating:** read the release notes and the CHANGELOG. Then take the new
version's `greencurve-<v>-linux-x64.tar.xz.sha256` from the release assets
and check it against `PKGBUILD.bin` on upstream main.

```sh
nix hash convert --hash-algo sha256 --to sri <sha256>          # tarball hash
nix develop -c nurl https://github.com/aufkrawall/green-curve <v>   # packaging hash
nix build .#greencurve -L --no-link
```

Update the version and both hashes in `default.nix`, the source line here,
and diff `packaging/arch/greencurve.service` against the previous tag. A new
`ExecStart` path or a new unit needs a matching change in the module.

**Removal condition:** switch to `pkgs.greencurve` once nixpkgs packages it
with its units. Delete this package if undervolting moves to another tool,
such as LACT.
