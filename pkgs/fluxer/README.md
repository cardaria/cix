# Fluxer package provenance

**Source:** the upstream stable AppImage, version `2026.1018.183123`
(published 2026-10-18), from `pkgs.fluxer.com`. The wrapper follows the
open nixpkgs PR [#552820](https://github.com/NixOS/nixpkgs/pull/552820)
(`fluxer-canary`, head `048a00c1fd9a3d038ad0804b00bff5b6f07bcc0e`), pointed
at the stable channel. A source build is impractical: the client needs the
whole monorepo, pnpm, a Cargo workspace and 22 Rust napi modules (see the PR
and the closed [#497870](https://github.com/NixOS/nixpkgs/pull/497870)).
x86_64-linux only.

**Local changes against the PR:**
- the stable channel instead of canary: `pname` `fluxer`, desktop entry
  `app.fluxer.FluxerDesktop.desktop` (the app's `desktopName`, so it also
  matches the Wayland app_id), installed under that name; its actions'
  hardcoded `/opt/Fluxer/fluxer` path is replaced with the wrapper;
- the AppImage ships its icon only at 1024x1024, a size the hicolor theme
  doesn't index, so launchers showed no icon; the build scales it to the
  standard sizes (16 to 512) with ImageMagick;
- the download URL points at `pkgs.fluxer.com`;
- `libva` is added to the FHS environment; without it Chromium decodes video
  on the CPU;
- no `passthru.updateScript`, aarch64 or maintainer entry.

`FLUXER_DISABLE_DESKTOP_FILE=1` stays set: without it the app writes its own
desktop entry on every launch, pointing at the unwrapped binary, which
cannot start outside the FHS environment. With it set, the app still runs
`xdg-mime default` for `fluxer://` unless it is already the handler, which is
why `dotfiles/mimeapps/mimeapps.list` names it.

**Build:** `nix build .#fluxer -L --no-link`.

**Updating:**

```sh
curl -sSL https://pkgs.fluxer.com/desktop/stable/linux/x64/latest.json   # version + appimage sha256
nix hash convert --hash-algo sha256 --to sri <sha256>
```

Put the version and hash in `default.nix`, build, and check that the
desktop entry's `Exec` lines and the icon path still match (the build fails
if a `--replace-fail` pattern is gone). Then start Fluxer from the launcher
and open a `fluxer://` link.

**Removal condition:** switch to a stable `fluxer` package once the locked
nixpkgs has it at a version no older than this one.
