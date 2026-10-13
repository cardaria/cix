# Chandra OCR package provenance

**Source:** [datalab-to/chandra](https://github.com/datalab-to/chandra), the
`chandra-src` flake input. `flake.lock` records its exact revision and hash;
the version comes from upstream's `pyproject.toml` (currently 0.2.0).
Neither the locked nixpkgs nor current nixos-unstable packages Chandra.

**Runtime:** nixpkgs' Python, Transformers, CUDA 13 PyTorch binary, and
Torchvision built for the RTX 5090 (`sm_120`). Accelerate, causal-conv1d and
Flash Linear Attention use the same PyTorch. CUDA vLLM is marked broken in
the locked nixpkgs, so this package uses Chandra's supported Hugging Face
backend. All dependencies come from nixpkgs; no pip environment or Docker.
NCCL and NVSHMEM also build only `sm_120`, avoiding unrelated GPU kernels.

**Local changes:**

- The locked nixpkgs Triton binary's CUDA library lookup returns a
  directory list instead of a filename string. Remove this override when
  nixpkgs fixes it.
- The exact markdownify 1.1.0 requirement is relaxed to the locked nixpkgs
  version.
- Document processing errors raise a Click error instead of being printed
  and skipped with a successful exit code. Not submitted upstream.

Upstream integration tests need a model download and a physical GPU, so
they run outside the build sandbox; import checks still run during the build.

**Weights:** the `chandra-model` flake input is the Hugging Face Git tree
with LFS downloading off: only small configs and hash pointers enter the
Nix store. The module generates a SHA-256 manifest from that immutable tree.
`cix ocr fetch` verifies the files and stores them under `~/AI/ocr/models`,
outside Git and the Nix store. The Python code is Apache-2.0; model terms
are in the downloaded `LICENSE` and upstream's model card.

**Updating:**

```sh
nix flake update chandra-src chandra-model
nix build .#chandra-ocr -L --no-link
```

Review the lock, rebuild, run `cix ocr fetch`, and repeat the image/PDF
runtime checks in [Local OCR](../../wiki/dev/local-ocr.md).

**Removal condition:** replace this with nixpkgs' Chandra once it supports
the same CUDA backend and CLI error handling. Reconsider vLLM when its
CUDA package builds and passes the OCR runtime checks on `draba`.
