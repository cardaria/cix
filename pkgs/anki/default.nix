{
  lib,
  anki,
  fetchFromGitHub,
  rustPlatform,
  yarn-berry_4,
}:
let
  version = "26.09.3";
  rev = "29bb700b951e3f0c0cb69b77c0180fc1fe33e6ba";
in
# Expires once nixpkgs catches up (nixpkgs PR #573799)
if lib.versionOlder anki.version version then
  anki.overrideAttrs (
    finalAttrs: old: {
      inherit version;

      src = fetchFromGitHub {
        owner = "ankitects";
        repo = "anki";
        rev = version;
        hash = "sha256-N55F8dDDRrCmA8GYP2QtfNs6QQrKhY7D2+yJO+4pqss=";
        fetchSubmodules = true;
      };

      cargoDeps = rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) pname version src;
        hash = "sha256-2atsCtbtS+0T1h+KqUXI3aGHJFQbQsIaCXSi5KFUz5E=";
      };

      missingHashes = ./missing-hashes.json;
      yarnOfflineCache = yarn-berry_4.fetchYarnBerryDeps {
        inherit (finalAttrs) src missingHashes patches;
        hash = "sha256-jjTN/jd9UgNefkFtIZ9RT9oGyxNlAO3WlMNHzjnlOCM=";
      };

      # Upstream bakes its pinned rev into the build hash shown in About
      buildPhase =
        builtins.replaceStrings [ "echo 666c2c64 " ] [ "echo ${builtins.substring 0 8 rev} " ]
          old.buildPhase;
    }
  )
else
  anki
