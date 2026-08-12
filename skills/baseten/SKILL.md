---
name: baseten
description: Deploy and operate BIS-LLM (Baseten Inference Stack v2) models on Baseten — MoE and large dense LLMs with token-based autoscaling, KV-aware routing, disaggregated serving, and speculative decoding. Use when pushing or debugging a BIS-LLM deployment, fetching metrics/logs, or promoting a BIS model between environments. Uses the `baseten` CLI (https://github.com/basetenlabs/baseten-cli) and `truss` CLI; no MCP.
---

# Baseten BIS-LLM

BIS-LLM (Baseten Inference Stack v2) is the engine for Mixture of Experts (MoE) models and large dense LLMs. It targets MoE families (DeepSeek V3.x/V4, Qwen3MoE, Kimi-K2/K3, Llama 4, GLM-4.7/5.x, GPT-OSS 120B, MiniMax 2.5) and the largest dense models, where the standard request-based autoscaler and a single-server inference engine both leave performance on the table. The v2 stack adds token-based autoscaling, KV-aware routing, disaggregated serving, expert parallel load balancing, and DP attention. Deployments mirror build artifacts to the Baseten Delivery Network (BDN) so cold starts stay fast.

BIS-LLM deployments expose OpenAI-compatible `/v1/chat/completions`, `/v1/completions`, and `/v1/embeddings` (where applicable). Standard OpenAI client SDKs work without modification. Structured outputs and function calling are supported through the standard OpenAI parameters.

## Tools

This skill uses two CLIs only — **no MCP**. The `baseten` MCP server is intentionally omitted as token-inefficient; the CLIs self-document via `--help` and emit machine-readable output (`--output json`, `--jq EXPR`).

| Tool | Provides | Install |
| --- | --- | --- |
| `baseten` CLI | Workspace + deployment lifecycle: push, watch, list, describe, predict, logs, metrics, promote, activate/deactivate. Open source at https://github.com/basetenlabs/baseten-cli. | `brew tap basetenlabs/baseten && brew install baseten` (macOS/Linux); or download from https://github.com/basetenlabs/baseten-cli/releases/latest onto PATH. |
| `truss` CLI | Author and push BIS-LLM `config.yaml` to Baseten. Needed for `truss push` / `truss watch` from a model directory. | `uv tool install truss` (or `pip install truss --upgrade`). Respect the user's package manager. |

Both CLIs are installed by `setup.sh` / `brew-setup.sh` (see `install_baseten_cli` and `ensure_venv` in `lib/shared.sh`).

## Setup

### Authenticate

```sh
baseten auth login --web      # interactive, browser-based
# or, for CI / headless:
export BASETEN_API_KEY=...    # create at https://app.baseten.co/settings/api_keys
```

`truss` uses its own credential file (`.trussrc`); run `truss login` once, or set `BASETEN_API_KEY` and pass `--remote <name>` in CI / multi-workspace flows. Do not commit `.trussrc`.

### Discover commands

```sh
baseten --help
baseten model --help
baseten model deployment --help
```

Every `baseten` command supports `--output text|json|jsonl|none` and `--jq EXPR` (implies `--output json`). Example: `baseten model list --jq '.models[].id'`.

## When to use BIS-LLM

Pick BIS-LLM for **MoE models** (DeepSeek V3/V4, R1, Kimi K2/K3, GLM 5.x, MiniMax 2.5, Qwen3 MoE, GPT-OSS-120B, Llama 4) **or workloads that need KV-cache-aware routing or disaggregated prefill/decode**. BIS-LLM is currently a co-engineering pilot — Enterprise-gated; contact support@baseten.co to enable.

For **dense text-generation LLMs** (Llama 3/4, Qwen 3/3.5, Mistral, Gemma, Phi, GPT-OSS-20B) use Engine-Builder-LLM instead. For **embedding/reranking/classification** use BEI or BEI-Bert. For speech/image/video/custom Python, ship a custom Truss. **This skill does not cover those engines** — reach for the hosted docs at https://docs.baseten.co/engines when you need them.

## Routing

**Skill references** (read on demand — complementary to the hosted docs):

- `references/bis-llm.md` — BIS-LLM `config.yaml` shape, engine selection (vLLM / TRT-LLM), runtime settings, token-based autoscaling, KV-aware routing, disaggregated serving, speculative decoding (Eagle/MTP/NGram), and the metrics to watch.
- `references/truss-push.md` — `truss push` / `truss watch` for BIS-LLM models: flags, dev vs published deployments, the agent watcher recipe, log markers, when to drop the watcher.
- `references/baseten-cli.md` — `baseten` CLI command reference for BIS workflows: `model push/watch/predict`, `model deployment logs/metrics/promote/describe/list`, output filtering with `--jq`.

## Quick start: deploy a BIS-LLM model

From a directory containing `config.yaml` with a `bis_llm:` block (see `references/bis-llm.md`):

```sh
# Publish + wait + stream logs (CI-friendly)
baseten model push --wait --tail
# or via truss:
truss push --wait --tail

# Iterative dev loop (live-patches code on save)
baseten model push --watch --tail
# or:
truss push --watch --tail

# Promote to production
baseten model deployment promote --model-id <mid> --deployment-id <did> --yes
```

Fetch metrics and logs (the source of truth for any perf/status claim):

```sh
baseten model deployment metrics --model-id <mid> --deployment-id <did> --mode series --since 6h
baseten model deployment logs    --model-id <mid> --deployment-id <did> --tail
```

Call a deployed BIS-LLM model (OpenAI-compatible):

```sh
baseten model predict --model-id <mid> --data '{"messages":[{"role":"user","content":"hello"}]}'
```

## Gotchas

- **BIS-LLM is Enterprise-gated.** KV-aware routing, disaggregated serving, and Eagle/MTP speculative decoding each require enablement; NGram speculation is generally available. Email support@baseten.co.
- **Don't speculate, query.** For any perf/status/error claim, fetch metrics and logs first (`baseten model deployment metrics`, `baseten model deployment logs`); don't estimate from priors. Log windows are bounded — a problem reported 5 min ago may have aged out of the default tail; use `--since` or `--start`/`--end` (max 7 days).
- **`engine_config` field names are engine-native.** vLLM uses `max_num_seqs` / `max_num_batched_tokens` / `max_model_len`; TRT-LLM uses `max_batch_size` / `max_num_tokens` / `max_seq_len`. Mixing them fails at startup with a clear error.
- **BIS-LLM autoscales on in-flight tokens, not request concurrency.** The deployment API rejects `concurrency_target` and `target_utilization_percentage`. Configure `target_in_flight_tokens` only (50K–150K is a sensible starting range for most LLMs).
- **Scale-to-zero is not supported.** Set `min_replica` to at least 1.
- **KV cache erodes on scale-down.** Keep `max_scale_down_rate` low (20% default) and `scale_down_delay` moderate (300–600s) for cache-sensitive workloads; abrupt drops cause TTFT spikes.
- **`truss push` / `baseten model push` default is a published deployment, not a dev one.** For an iterative dev loop, use `--watch` (or `truss watch` / `baseten model watch` afterwards). The watcher keeps the dev deployment warm by default; pass `--watch-no-keepalive` (baseten) / `--no-keepalive` (truss watch) to let it scale to zero.
- **`--watch-hot-reload` does not re-run `__init__`/`load`.** Only valid when only `predict()` changed and no new module-level imports / state. When unsure, drop the flag.
- **`.trussrc` holds credentials.** Do not commit it. In CI, prefer `BASETEN_API_KEY` + `--remote <name>`.

## Further reading

- BIS-LLM overview: https://docs.baseten.co/engines/bis-llm
- BIS-LLM config reference: https://docs.baseten.co/engines/bis-llm/bis-llm-config
- Advanced features (KV routing, disagg, speculation): https://docs.baseten.co/engines/bis-llm/advanced-features
- Autoscaling BIS-LLM: https://docs.baseten.co/engines/performance-concepts/autoscaling-engines#bis-llm
- Migrate from Engine-Builder-LLM (v1): https://docs.baseten.co/engines/bis-llm/migrate-from-v1
- `baseten` CLI overview: https://docs.baseten.co/reference/cli/baseten/overview
- `baseten` CLI repo: https://github.com/basetenlabs/baseten-cli
- `truss` CLI overview: https://docs.baseten.co/reference/cli/truss/overview
- Truss config schema (authoritative): https://github.com/basetenlabs/truss/blob/main/truss/config.schema.json
- Docs index (when you can't find something): https://docs.baseten.co/llms.txt
