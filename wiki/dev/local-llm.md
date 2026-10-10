---
title: Local LLM
category: dev
tags: [llm, opencode, ninfer, llama-swap, qwen, cuda, rtx-5090]
updated: 2026-10-10
---

# Local LLM

Qwen3.8-27B runs on the RTX 5090 through NInfer and is used from OpenCode. Two
profiles of the same model are defined. llama-swap starts whichever one a request
asks for, holds the request until the model is ready, and unloads it after 15
idle minutes. Only one profile can hold the GPU at a time.

## Contents

- [Profiles](#profiles)
- [Using it from OpenCode](#using-it-from-opencode)
- [Lifecycle](#lifecycle)
- [Commands](#commands)
- [The `~/AI` folder](#the-ai-folder)
- [Other clients](#other-clients)
- [Updating](#updating)

## Profiles

| OpenCode model | Context | Speculative decoding | VRAM | Use |
| --- | --- | --- | --- | --- |
| **Qwen3.8 27B · Fast 128K** (default) | 131,072 | DFlash2, 7 drafts | 21.4 + 6.6 GiB, ~4.8 GiB free | everyday coding and agent loops |
| **Qwen3.8 27B · Long 256K** | 262,144 (native maximum) | MTP, 3 drafts | 19.7 + 9.6 GiB, ~1.6 GiB free | huge repos, logs, documents |

Both run the same pinned NVFP4 artifact with FP8 KV cache, two request lanes
sharing one KV pool, and preserved thinking. Speculative decoding is
lossless: it changes speed, never output. Measured on Fast: 270–390 tok/s
decode and 12.5k tok/s prefill. Long can't use DFlash2: at 262K it would need
10.6 GiB beyond the weights, and only about 9.5 GiB is left. VRAM is weights
plus runtime (KV pool, lane state, CUDA graphs), measured on a 5090 with no
display attached.

Everything above is defined once in the `profiles` list of
`modules/home/llm/default.nix`. llama-swap and OpenCode both read it.

## Using it from OpenCode

```sh
opencode                              # starts on Fast
opencode -m local/qwen3.8-27b-long    # start on Long
```

| Action | How |
| --- | --- |
| Switch Fast ↔ Long | `/models`, pick the entry. The status bar shows the active name |
| Change thinking depth | cycle variants (`none`, `low`, `medium`, `xhigh`) with the variant keybind. The default is the model's own, `xhigh`. Those are the only levels the Qwen3.8 template accepts |

- A switch waits until the other profile's running requests finish, then
  swaps. A cold start takes about 5 seconds: weights 2 s, pinned host cache
  1 s, CUDA graphs 1 s.
- Titles are generated with thinking off (the first variant).
- Each turn reuses about 99% of the prompt from NInfer's prefix cache, so an
  agent step starts in under 100 ms. OpenCode's system prompt and tools are
  about 10K tokens.
- Compaction starts at the context size minus 32,000 output tokens (about
  99K on Fast). Old tool output is pruned first.
- No MCP servers, LSP or formatters are configured. Keep additions small:
  every tool definition costs the 27B model context and focus.

## Lifecycle

| Event | What happens |
| --- | --- |
| Login | `llama-swap.service` (user) listens on localhost port 8080. No GPU use |
| First request for a profile | NInfer starts. The request waits for `/health`, then streams |
| Request for the other profile | swap after in-flight requests drain. Never two profiles at once |
| 15 min after the last finished request | NInfer gets SIGTERM and the VRAM is freed. Open connections don't count |
| Logout | the user service stops and takes NInfer with it |

The service starts a fixed store worker with the `cix-compute` group;
the desktop session does not have that group's GPU access. The worker
sets the compute CUDA UUID before starting llama-swap. See
[GPU access](../architecture/gpu-access.md).

## Commands

```sh
cix-llm             # loaded profile, NInfer queue/KV, 5090 VRAM
cix-llm unload      # free the GPU now (e.g. before ComfyUI or suspend)
cix-llm logs        # follow llama-swap and NInfer output
cix-llm fetch       # download + sha256-verify the pinned model
cix-llm ui          # llama-swap web UI: running models, logs, captures
```

`cix-llm status` reads NInfer directly, so checking doesn't reset the idle
timer. GPU statistics use the same fixed NVIDIA monitoring executable as
System Monitor. The logs are also in the journal:

```sh
journalctl --user -u llama-swap -b
systemctl --user status llama-swap
```

## The `~/AI` folder

`~/AI` (`$XDG_AI_DIR`) holds model weights, one folder per capability:
`llm/models` and `ocr/models`, both created at login.
It is outside the repo on purpose. Git tracks how each model is used and
which exact file it is (Hugging Face repo, revision, SHA-256 in the module),
never the weights. On a fresh install, run `cix-llm fetch` (22 GiB).
Chandra uses the sibling OCR folder; its locked model and CLI are documented
in [Local OCR](local-ocr.md).

## Other clients

The endpoint speaks OpenAI Chat Completions/Responses and Anthropic Messages:

```sh
curl http://localhost:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"qwen3.8-27b","messages":[{"role":"user","content":"hi"}],"reasoning_effort":"none"}'
```

`qwen3.8-27b` means "whichever profile is loaded, else Fast". Name a profile
(`qwen3.8-27b-long`) to force it.

## Updating

- NInfer: see `pkgs/ninfer/README.md`, then re-check both profiles.
- Model: change `model` in `modules/home/llm/default.nix` (repo, revision,
  file, hash), rebuild, run `cix-llm fetch`.
- A profile: edit its entry in `profiles`. If DFlash2 misbehaves, change
  Fast's `spec` to MTP (`--spec mtp --draft-tokens 3 --lm-head-draft`).

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Requests fail right away | `cix-llm`: is the model present (`cix-llm fetch`)? `cix-llm logs` shows NInfer's error |
| `cix-llm fetch` reports a hash mismatch | the bad download is deleted; run it again. A repeated mismatch means the file at the pinned revision differs from `model.sha256` |
| OpenCode: "upstream command exited prematurely" after about 90 s | the profile can't start. `cix-llm logs` shows why, often "runtime reservation requires … bytes": something else holds 5090 VRAM (`nvidia-smi`) |
| `cudaErrorLaunchTimeout` | the 5090 is driving a display (watchdog). Keep displays on the 5060 |
| NInfer starts on the 5060 or loads both cards | check the fixed worker selected by `systemctl --user cat llama-swap`; its CUDA UUID comes from `cix.computeGpu` |
| First reply is slow | a cold start or a swap waiting for another request to finish; watch `cix-llm logs` |
| Model stays loaded | something is still requesting: `cix-llm ui` → Activity. Or `cix-llm unload` |
| Tool calls appear as plain text | `cix-llm logs` for NInfer's tool-call parse warning; try a lower thinking variant |
| HTTP 400 "Unexpected reasoning effort" | a client sent an effort the template lacks (`high`, `max`). Use `none`, `low`, `medium` or `xhigh` |
| Host RAM: ~9.5 GiB pinned while loaded | NInfer's host prefix cache; it is freed with the model |
| Slow suspend | VRAM is saved to `/var/tmp`. `cix-llm unload` first |

## Related

- [Developer tools](tools.md) · [Nix packaging](nix-packaging.md) · [draba → NVIDIA](../architecture/draba.md)
- memory: `local-llm-stack`, `ai-folder-layout`
