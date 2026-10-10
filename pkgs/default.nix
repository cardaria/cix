{ pkgs, chandraSrc }:
{
  chandra-ocr = pkgs.callPackage ./chandra-ocr { inherit chandraSrc; };
  krohnkite = pkgs.callPackage ./krohnkite { };
  ninfer = pkgs.callPackage ./ninfer { };
  nvidia-vaapi-driver = pkgs.callPackage ./nvidia-vaapi-driver { };
}
