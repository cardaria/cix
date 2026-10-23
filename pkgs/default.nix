{
  pkgs,
  cudaPkgs,
  chandraSrc,
}:
{
  anki = pkgs.callPackage ./anki { };
  chandra-ocr = cudaPkgs.callPackage ./chandra-ocr { inherit chandraSrc; };
  fluxer = pkgs.callPackage ./fluxer { };
  greencurve = pkgs.callPackage ./greencurve { };
  krohnkite = pkgs.callPackage ./krohnkite { };
  ninfer = cudaPkgs.callPackage ./ninfer { };
  nvidia-vaapi-driver = pkgs.callPackage ./nvidia-vaapi-driver { };
}
