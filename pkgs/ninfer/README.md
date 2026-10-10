# NInfer package provenance

**Source:** [Neroued/ninfer](https://github.com/Neroued/ninfer) at master commit
`81c8ce093b2c1646a87566a8e59d807fcf0ec95c` (2026-10-07). Upstream publishes no
releases or install target, so the version is `0-unstable-<commit date>` and
`installPhase` copies `ninfer`, `ninfer-serve` and `ninfer-perplexity` out of
the build tree.

**Build:** CUDA 13 (`cudaPackages_13` and its `backendStdenv`), because
upstream validates on CUDA 13.1 and benchmarks on 13.4. nixpkgs' default
`cudaPackages` is 12.x. The only supported architecture is `sm_120a` (RTX
5090). All third-party code is vendored in the source tree, so nothing is
downloaded at configure time. Tests and benchmarks stay off. They need the GPU,
which the build sandbox doesn't have. `autoAddDriverRunpath` points the
binaries at the running driver's `libcuda`.

The derivation is written for this repo. Its shape follows the community
[oakshortbow/ninfer-flake](https://github.com/oakshortbow/ninfer-flake), which
uses CUDA 12.9 and its own nixpkgs pin.

**Local changes:** no patches. `postFixup` strips the `cuda_nvcc` store path
that nvcc writes into the fatbin metadata. Left in place, it would pull nvcc
and the whole GCC toolchain (~700 MiB) into the runtime closure.
`disallowedReferences` fails the build if the path returns.

**Model artifacts** are not packaged. `modules/home/llm/default.nix` pins the
Hugging Face revision and SHA-256 of the weights, and `cix-llm fetch`
downloads them to `~/AI/llm/models/`.

**Updating:** pick a newer master commit after reading its changelog and open
issues. Then:

```sh
nix develop -c nurl https://github.com/Neroued/ninfer <commit>   # new hash
nix build .#ninfer -L --no-link
```

Update the commit, hash and version date here and in `default.nix`, then
re-run the runtime checks in [Local LLM](../../wiki/dev/local-llm.md). Upstream
performance tables were measured at `7f6aafedb5f20200def820cfe51ab81c09c20eeb`.
Fall back to that commit if a newer one misbehaves.

**Removal condition:** replace this with `pkgs.ninfer` once nixpkgs packages
NInfer with CUDA 13 and `sm_120a`. Delete it if the local LLM stack moves to
another runtime.
