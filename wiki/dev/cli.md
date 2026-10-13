---
title: cix CLI
category: dev
tags: [cli, cix, update, llm, ocr]
updated: 2026-10-13
---

# cix CLI

One command, `cix`, for everything this repo adds to the shell. Every level
has `--help`:

```sh
cix --help
cix llm --help
```

## Commands

| Command | Does | Details |
| --- | --- | --- |
| `cix update` | update inputs, preview, apply the system | [Deployment](../deployment.md#build-and-apply) |
| `cix llm` | status, unload, logs, tps, fetch, ui of the local LLM | [Local LLM](local-llm.md) |
| `cix ocr` | convert PDFs and images, fetch and verify the model | [Local OCR](local-ocr.md) |

`cix help <command>` is the same as `cix <command> --help`.

## Adding a command

`modules/home/cix/default.nix` owns the dispatcher and the `cix.commands`
option. The module that owns a feature registers its program there, and
the name, the `--help` line and the dispatch all follow from it:

```nix
cix.commands.<name> = {
  description = "One line for cix --help";
  package = <program>;
};
```

The program is not installed on its own: only `cix` is on `PATH`.
It starts with `Usage: cix <name> …` in its own `--help`.

## Not part of the CLI

`cix-llm-worker` and `cix-ocr-worker` are fixed entrypoints for the GPU
group and never run by hand ([GPU access](../architecture/gpu-access.md)).
`cix-desktop-gpu` is a boot-time helper for KWin and Plex.
