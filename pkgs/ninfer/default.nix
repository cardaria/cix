{
  autoAddDriverRunpath,
  cmake,
  cudaPackages_13,
  curl,
  fetchFromGitHub,
  ffmpeg-headless,
  hwloc,
  lib,
  liburing,
  ninja,
  pkg-config,
  removeReferencesTo,
}:

let
  cuda = cudaPackages_13;
in
cuda.backendStdenv.mkDerivation (finalAttrs: {
  pname = "ninfer";
  version = "0-unstable-2026-10-16";

  src = fetchFromGitHub {
    owner = "Neroued";
    repo = "ninfer";
    rev = "64d10fbf9f8e6bfc79ab0570b94674c5b9997929";
    hash = "sha256-vwCnXyQPR6xY0r3JEg53EuHQkd4WbnKsNTvBtrL7LxM=";
  };

  nativeBuildInputs = [
    autoAddDriverRunpath
    cmake
    cuda.cuda_nvcc
    ninja
    pkg-config
    removeReferencesTo
  ];

  buildInputs = [
    cuda.cccl
    cuda.cuda_cudart
    cuda.cuda_nvtx
    curl
    ffmpeg-headless
    hwloc
    liburing
  ];

  cmakeFlags = [
    # The only architecture upstream compiles for; it rejects any other value
    (lib.cmakeFeature "CMAKE_CUDA_ARCHITECTURES" "120a")
    (lib.cmakeBool "NINFER_BUILD_APPS" true)
    (lib.cmakeBool "BUILD_TESTING" false)
    (lib.cmakeBool "NINFER_BUILD_BENCHMARKS" false)
  ];

  # Upstream has no install target; the binaries stay in the build tree
  installPhase = ''
    runHook preInstall
    install -Dm755 -t "$out/bin" apps/ninfer apps/ninfer-serve apps/ninfer-perplexity
    runHook postInstall
  '';

  # nvcc records its library paths in the fatbin; nothing reads them at runtime
  postFixup = ''
    remove-references-to -t ${cuda.cuda_nvcc} "$out"/bin/*
  '';
  disallowedReferences = [ cuda.cuda_nvcc ];

  meta = {
    description = "Single-GPU inference engine for Qwen3.5-family checkpoints on the RTX 5090";
    homepage = "https://github.com/Neroued/ninfer";
    license = lib.licenses.asl20;
    mainProgram = "ninfer-serve";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
