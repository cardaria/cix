# Plex icon

`plex.png` is the original 1024×1024 PNG extracted from the macOSicons ICNS
download, without resizing or redrawing.

- Icon: [plex by vale](https://macosicons.com/?icon=PjliPTDhh6)
- Original download: [ICNS](https://s3-new.macosicons.com/macosicons/parse/plex_PjliPTDhh6_icns-f54023acc2.icns)

`modules/home/apps/plex.nix` copies this asset into the Nix store and gives
Plex's desktop entry an absolute icon path. Rebuilds need no icon download
and do not depend on the selected icon theme.
