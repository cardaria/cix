{ pkgs, chandraSrc }:
{
  chandra-ocr = pkgs.callPackage ./chandra-ocr { inherit chandraSrc; };
  fluxer-canary = pkgs.callPackage ./fluxer-canary { };
  krohnkite = pkgs.callPackage ./krohnkite { };
  ninfer = pkgs.callPackage ./ninfer { };
  nvidia-vaapi-driver = pkgs.callPackage ./nvidia-vaapi-driver { };
}
