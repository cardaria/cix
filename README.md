<div align="center">

# cix

**My personal NixOS configuration**

Every machine I run, declared in one flake,<br>
with Home Manager for everything on the user side.

[![NixOS unstable](https://img.shields.io/badge/NixOS-unstable-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![Home Manager](https://img.shields.io/badge/Home_Manager-integrated-7EBAE4?style=flat-square&logo=nixos&logoColor=white)](https://github.com/nix-community/home-manager)
[![KDE Plasma 6](https://img.shields.io/badge/KDE_Plasma-6-1D99F3?style=flat-square&logo=kde&logoColor=white)](https://kde.org/plasma-desktop/)

[Hosts](#hosts) · [System](#current-system) · [Layout](#layout) · [Usage](#usage) · [Docs](#documentation)

</div>

<br>

## Hosts

<div align="center">
<table>
  <tr>
    <th align="left">Host</th>
    <th align="left">Role</th>
    <th align="left">Specs</th>
  </tr>
  <tr>
    <td align="left"><code>draba</code></td>
    <td align="left">Workstation</td>
    <td align="left"><sub><a href="https://www.amd.com/en/products/processors/desktops/ryzen/9000-series/amd-ryzen-9-9950x3d.html">Ryzen 9 9950X3D</a> · <a href="https://www.gigabyte.com/Graphics-Card/GV-N5090AORUS-M-32GD">RTX 5090</a> + <a href="https://www.gigabyte.com/Graphics-Card/GV-N5060OC-8GL">RTX 5060</a> · <a href="https://www.corsair.com/us/en/p/memory/cmk96gx5m2e6000z36/vengeance-96gb-2x48gb-ddr5-dram-6000mt-s-cl36-amd-expo-intel-xmp-memory-kit-cmk96gx5m2e6000z36">96 GB DDR5</a></sub></td>
  </tr>
</table>
</div>

## Current system

<div align="center">
<table>
  <tr>
    <td align="left"><b>System</b></td>
    <td align="left"><img src="https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nix-snowflake-colours.svg" width="18" height="18" align="absmiddle">&nbsp; <a href="https://github.com/NixOS/nixpkgs">NixOS unstable</a> · <a href="https://wiki.nixos.org/wiki/Flakes">Flakes</a></td>
  </tr>
  <tr>
    <td align="left"><b>Home</b></td>
    <td align="left"><img src="https://github.com/nix-community.png?size=36" width="18" height="18" align="absmiddle">&nbsp; <a href="https://github.com/nix-community/home-manager">Home Manager</a> · <a href="https://github.com/nix-community/plasma-manager">plasma-manager</a></td>
  </tr>
  <tr>
    <td align="left"><b>Desktop</b></td>
    <td align="left"><img src="https://cdn.simpleicons.org/kdeplasma" width="18" height="18" align="absmiddle">&nbsp; <a href="https://kde.org/plasma-desktop/">KDE Plasma 6</a> · <a href="https://codeberg.org/anametologin/Krohnkite">Krohnkite</a> · <a href="https://wayland.freedesktop.org">Wayland</a></td>
  </tr>
  <tr>
    <td align="left"><b>Login</b></td>
    <td align="left"><img src="https://cdn.simpleicons.org/kde" width="18" height="18" align="absmiddle">&nbsp; <a href="https://invent.kde.org/plasma/plasma-login-manager">Plasma Login Manager</a></td>
  </tr>
  <tr>
    <td align="left"><b>Shell</b></td>
    <td align="left"><img src="https://cdn.simpleicons.org/zsh" width="18" height="18" align="absmiddle">&nbsp; <a href="https://github.com/zsh-users/zsh">zsh</a> · <a href="https://github.com/junegunn/fzf">fzf</a></td>
  </tr>
  <tr>
    <td align="left"><b>Terminal</b></td>
    <td align="left"><img src="https://raw.githubusercontent.com/ghostty-org/ghostty/main/images/icons/icon_128.png" width="18" height="18" align="absmiddle">&nbsp; <a href="https://github.com/ghostty-org/ghostty">Ghostty</a></td>
  </tr>
  <tr>
    <td align="left"><b>Editor</b></td>
    <td align="left"><img src="https://raw.githubusercontent.com/zed-industries/zed/main/crates/zed/resources/app-icon.png" width="18" height="18" align="absmiddle">&nbsp; <a href="https://github.com/zed-industries/zed">Zed</a></td>
  </tr>
  <tr>
    <td align="left"><b>Boot</b></td>
    <td align="left"><img src="https://cdn.simpleicons.org/gnu" width="18" height="18" align="absmiddle">&nbsp; <a href="https://www.gnu.org/software/grub/">GRUB</a></td>
  </tr>
  <tr>
    <td align="left"><b>Storage</b></td>
    <td align="left"><img src="https://github.com/nix-community.png?size=36" width="18" height="18" align="absmiddle">&nbsp; <a href="https://github.com/nix-community/disko">Disko</a> · <a href="https://btrfs.readthedocs.io">btrfs</a></td>
  </tr>
  <tr>
    <td align="left"><b>Secrets</b></td>
    <td align="left"><img src="https://cdn.simpleicons.org/1password" width="18" height="18" align="absmiddle">&nbsp; <a href="https://1password.com">1Password</a> · <a href="https://github.com/ryantm/agenix">agenix</a></td>
  </tr>
  <tr>
    <td align="left"><b>Local AI</b></td>
    <td align="left"><img src="https://cdn.simpleicons.org/qwen" width="18" height="18" align="absmiddle">&nbsp; <a href="https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer">Qwen3.8-27B</a> · <a href="https://huggingface.co/datalab-to/chandra-ocr-2">Chandra OCR 2</a></td>
  </tr>
</table>
</div>

## Layout

```text
cix/
├── flake.nix         inputs, hosts, packages, checks
├── hosts/            one folder per machine
├── modules/
│   ├── nixos/        shared system modules
│   └── home/         Home Manager modules
│       ├── apps/     applications
│       ├── llm/      local LLM: NInfer, llama-swap, OpenCode
│       ├── ocr/      Chandra OCR 2, cix-ocr
│       └── wayland/  Plasma settings, fonts
├── home/cardaria/    user entry point and imports
├── dotfiles/         live app configs
├── pkgs/             local packages
├── secrets/          agenix-encrypted secrets
└── wiki/             documentation
```

## Usage

```sh
cix-update
```

Updates the inputs, builds, previews and asks before applying. It picks the
right activation for the booted entry, including `display-5090`
([Deployment](wiki/deployment.md)).

> [!TIP]
> Changes under `dotfiles/` apply on the application's reload, without a rebuild.

## Documentation

- **[Wiki](wiki/README.md)**: start with [Deployment](wiki/deployment.md)
- **[AGENTS.md](AGENTS.md)**: the rules coding agents follow

<br>

<div align="center">
<sub>
Ideas and inspiration from the configurations of
<a href="https://github.com/basnijholt">@basnijholt</a>,
<a href="https://github.com/reo101">@reo101</a>,
<a href="https://github.com/74k1">@74k1</a> and
<a href="https://github.com/Shangshui0302">@Shangshui0302</a>.
</sub>
</div>
