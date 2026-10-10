# Fluxer Canary package provenance

**Source:** the upstream canary AppImage, version `2026.1009.45608`
(published 2026-10-09), from `pkgs.fluxer.com`. The wrapper follows the
open nixpkgs PR [#552820](https://github.com/NixOS/nixpkgs/pull/552820)
(`fluxer-canary`, head `048a00c1fd9a3d038ad0804b00bff5b6f07bcc0e`). A source
build is impractical: the client needs the whole monorepo, pnpm, a Cargo
workspace and 22 Rust napi modules (see the PR and the closed
[#497870](https://github.com/NixOS/nixpkgs/pull/497870)). Canary on
purpose: it gets builds first (stable was at `2026.1006.171735` when this
was written). x86_64-linux only.

**Local changes against the PR:**
- the AppImage's desktop entry is now `app.fluxer.FluxerDesktopCanary.desktop`
  (the app's `desktopName`, so it also matches the Wayland app_id); it is
  installed under that name, and its actions' hardcoded `/opt/fluxer-canary`
  path is replaced with the wrapper;
- the AppImage ships its icon only at 1024x1024, a size the hicolor theme
  doesn't index, so launchers showed no icon; the build scales it to the
  standard sizes (16 to 512) with ImageMagick;
- the download URL points at `pkgs.fluxer.com`, where
  `api.canary.fluxer.app/dl/…` now redirects;
- `libva` is added to the FHS environment; without it Chromium decodes video
  on the CPU;
- no `passthru.updateScript`, aarch64 or maintainer entry.

`FLUXER_DISABLE_DESKTOP_FILE=1` stays set: without it the app writes its own
desktop entry on every launch, pointing at the unwrapped binary, which
cannot start outside the FHS environment. With it set, the app still runs
`xdg-mime default` for `fluxer://` unless it is already the handler, which is
why `dotfiles/mimeapps/mimeapps.list` names it.

**Build:** `nix build .#fluxer-canary -L --no-link`.

**Updating:** canary moves several times a day; bump when needed.

```sh
curl -sSL https://pkgs.fluxer.com/desktop/canary/linux/x64/latest.json   # version + appimage sha256
nix hash convert --hash-algo sha256 --to sri <sha256>
```

Put the version and hash in `default.nix`, build, and check that the
desktop entry's `Exec` lines and the icon path still match (the build fails
if a `--replace-fail` pattern is gone). Then start Fluxer from the launcher
and open a `fluxer://` link.

**Removal condition:** switch to `pkgs.fluxer-canary` (or a stable `fluxer`
package, if upstream resumes stable releases) once the locked nixpkgs has it
at a version no older than this one.
