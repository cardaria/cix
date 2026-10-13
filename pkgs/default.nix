{
  pkgs,
  cudaPkgs,
  chandraSrc,
}:
{
  chandra-ocr = cudaPkgs.callPackage ./chandra-ocr { inherit chandraSrc; };
  fluxer-canary = pkgs.callPackage ./fluxer-canary { };
  greencurve = pkgs.callPackage ./greencurve { };
  krohnkite = pkgs.callPackage ./krohnkite { };
  ninfer = cudaPkgs.callPackage ./ninfer { };
  nvidia-vaapi-driver = pkgs.callPackage ./nvidia-vaapi-driver { };
}
