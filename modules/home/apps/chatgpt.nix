{ lib, pkgs, ... }:
let
  version = "26.1013.40934";
  chatgpt = pkgs.chatgpt.overrideAttrs (
    old:
    lib.optionalAttrs (lib.versionOlder pkgs.chatgpt.version version) {
      inherit version;
      src = pkgs.fetchurl {
        url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
        hash = "sha256-PKWef5pmQbni+5rWgGg3hLWrgCb/dBj7ISoOvl3zodc=";
      };
    }
    // {
      # Remove when upstream offers native Linux window decorations
      # https://github.com/openai/codex/issues/38595
      postPatch = old.postPatch + ''
        asar extract usr/lib/chatgpt/resources/app.asar native-titlebar-app
        substituteInPlace native-titlebar-app/.vite/build/main-*.js \
          --replace-fail 'case`primary`:return n===`darwin`?' \
            'case`primary`:return n===`linux`?{titleBarStyle:`default`}:n===`darwin`?' \
          --replace-fail 'case`detached`:return n===`darwin`?' \
            'case`detached`:return n===`linux`?{titleBarStyle:`default`}:n===`darwin`?' \
          --replace-fail '(process.platform===`win32`||process.platform===`linux`)&&(this.windowZooms.set' \
            '(process.platform===`win32`)&&(this.windowZooms.set' \
          --replace-fail 'installApplicationMenuTitleBarOverlaySync(e,t){if(process.platform!==`win32`' \
            'installApplicationMenuTitleBarOverlaySync(e,t){if(process.platform===`linux`||process.platform!==`win32`'
        asar pack native-titlebar-app usr/lib/chatgpt/resources/app.asar \
          --unpack-dir "node_modules/{$unpackedDirs}"
      '';
    }
  );
in
{
  home.packages = [ chatgpt ];
}
