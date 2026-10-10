---
title: Local OCR
category: dev
tags: [ocr, chandra, cuda, models, pdf]
updated: 2026-10-10
---

# Local OCR

`cix-ocr` converts PDFs and images into Markdown, HTML and layout metadata
with the official Chandra OCR 2 model on the RTX 5090.

## Layout

| Path | Purpose |
| --- | --- |
| `modules/home/ocr/` | CLI defaults and verified model download |
| `pkgs/chandra-ocr/` | native Python application and CUDA dependencies |
| `~/AI/ocr/models/chandra-ocr-2/<revision>/` | weights, processor, tokenizer and model licence |
| output directory you choose | extracted documents and images |

The model uses full BF16 precision. There is no GPU service at login: each
command loads the model once, processes the input, then exits and releases
the VRAM. Multiple OCR commands wait their turn rather than loading duplicate
weights. A directory invocation reuses the loaded model for every file.

The CLI runs a fixed store worker with the `cix-compute` group, keeping the
normal user identity and file access. The desktop session itself cannot
open the 5090. See [GPU access](../architecture/gpu-access.md).

## Settings

| Setting | Default |
| --- | --- |
| Backend | Hugging Face Transformers, entirely on CUDA |
| Attention | PyTorch SDPA; fused linear attention and causal convolution |
| Precision | BF16 weights; upstream cache settings |
| Batch | one page; override with `--batch-size` only after checking VRAM |
| Output limit | upstream 12,384 tokens per page |
| Image resolution | upstream defaults: 192 DPI PDF rendering, preserved model processor settings |
| Sampling | upstream model's generation settings |
| Headers / footers | excluded; `--include-headers-footers` includes them |
| Images / HTML | saved; `--no-images` / `--no-html` disables them |

Chandra and Qwen each need GPU memory. Before a large OCR job, use
`cix-llm unload` and pause clients that might reload Qwen. OCR does not stop
an active coding request. Inspect memory with `nvidia-smi`.

## First install

```sh
cix-ocr fetch
cix-ocr status
cix-ocr verify
```

Fetch uses the Git revision and SHA-256 hashes locked in `chandra-model`.
The Nix store holds only small configuration files and LFS hash pointers.
Fetch reuses a matching Hugging Face cache snapshot with btrfs reflinks, verifies each
file, and downloads only missing files. New revisions get separate folders;
existing weights stay available for rollback. Weights are about 9.9 GiB.

OCR runs offline after fetch. A missing model produces an error with the
fetch command; it does not silently fall back to CPU or a hosted API.

## Extract a document

```sh
cix-ocr ~/Documents/scan.pdf ~/Documents/ocr-output
cix-ocr ~/Pictures/page.png ~/Documents/ocr-output
cix-ocr ~/Documents/scans ~/Documents/ocr-output
```

Each file gets its own output subdirectory containing `<name>.md`,
`<name>.html`, `<name>_metadata.json` and any extracted images.

## Select pages or options

```sh
cix-ocr ~/Documents/scan.pdf ~/Documents/ocr-output --page-range '1-3,7'
cix-ocr ~/Documents/scan.pdf ~/Documents/ocr-output --include-headers-footers
cix-ocr --help
```

## Update

```sh
cd ~/Repos/cix
nix flake update chandra-src chandra-model
nix flake check
```

Build and apply through [Deployment](../deployment.md), then run
`cix-ocr fetch`. A full `nix flake update` also updates both Chandra inputs;
nixpkgs supplies updated Python/CUDA dependencies. Inspect the lock changes
and repeat a representative image and PDF before committing an update.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Model missing or unverified | `cix-ocr fetch`; `cix-ocr verify` checks every hash again |
| Download/hash error | a download that fails its hash is deleted; run `cix-ocr fetch` again. A repeated mismatch means upstream no longer matches the locked metadata |
| CUDA out of memory | `cix-llm unload`, pause other GPU clients, use batch size 1 |
| Runs on the 5060 | `cix-ocr` sets `CUDA_VISIBLE_DEVICES` to the 5090's UUID (`cix.computeGpu`); check it is the 5090's in `nvidia-smi -L` |
| CPU fallback expected | CUDA is required; check `nvidia-smi` and the running driver |
| OCR command appears to wait | another OCR command holds the lock; it releases it on exit |
| Document processing fails | command exits unsuccessfully; inspect the error and input file |
| Slow first page | model loading and Triton kernel compilation; subsequent pages reuse both |

## Related

- [Local LLM](local-llm.md) · [Nix packaging](nix-packaging.md) · [Deployment](../deployment.md)
- [Upstream model](https://huggingface.co/datalab-to/chandra-ocr-2)
- memory: `local-ocr-stack`
