# BIS-LLM configuration, features, autoscaling, and metrics

BIS-LLM (Baseten Inference Stack v2) deployments are configured entirely in the `bis_llm` block of `config.yaml`. There's no engine build step: the deploy is config-only, and the settings under `bis_llm.config` are passed to a prebuilt serving image. Push the config with `truss push` or `baseten model push` (see `truss-push.md` and `baseten-cli.md`).

Authoritative docs: <https://docs.baseten.co/engines/bis-llm/bis-llm-config> (config), <https://docs.baseten.co/engines/bis-llm/advanced-features> (KV routing / disagg / speculation), <https://docs.baseten.co/engines/performance-concepts/autoscaling-engines#bis-llm> (autoscaling).

## Configuration structure

A BIS-LLM `config.yaml` has a top-level `bis_llm` block alongside the standard `model_name`, `resources`, and `weights` fields:

```yaml config.yaml
model_name: qwen2-5-7b
resources:
  accelerator: H100:1
  use_gpu: true
weights:
  - source: hf://Qwen/Qwen2.5-7B-Instruct
    mount_location: /models/qwen
bis_llm:
  version: "<version>"          # from your Baseten representative, or the platform default (omit)
  config:
    engine_backend: vllm
    checkpoint_name: Qwen/Qwen2.5-7B-Instruct
    model_name: Qwen/Qwen2.5-7B-Instruct
    tensor_parallel_size: 1
    engine_config:
      max_num_seqs: 16
      max_num_batched_tokens: 8192
      max_model_len: 32768
  additional_autoscaling_config:
    metrics:
      - name: in_flight_tokens
        target: 16000
```

- `bis_llm.version` selects the serving stack version. Omit it to use the platform default, or set the value your Baseten representative provides.
- `bis_llm.config` holds the engine and runtime settings covered below.
- `bis_llm.additional_autoscaling_config` sets token-based autoscaling (see "Autoscaling" below).
- `weights` mirrors model files to the Baseten Delivery Network (BDN) for fast cold starts.

## Engine

BIS-LLM runs your model on one of two inference engines. Set `engine_backend` in `bis_llm.config`:

```yaml
bis_llm:
  config:
    engine_backend: vllm   # or: trtllm
```

Baseten resolves the latest certified multi-arch serving image that passed model-performance CI for that engine.

- `engine_backend` (string): `trtllm` (TensorRT-LLM) or `vllm` (vLLM). Required unless `gpuTRTImage` is set.
- `gpuTRTImage` (string): a specific serving image; takes precedence over `engine_backend`.

### Engine-specific runtime settings

Each engine takes its runtime settings under `engine_config`, using that engine's **native field names**. The two vocabularies don't overlap. Passing TRT-LLM names to vLLM fails at startup:

```
ValueError: engine_config on the vLLM backend uses TRT-LLM-flavored field names
('max_batch_size' → 'max_num_seqs', 'max_num_tokens' → 'max_num_batched_tokens',
'max_seq_len' → 'max_model_len'). Use vLLM's own names; each backend's
engine_config is native to that backend.
```

**vLLM:**

```yaml
bis_llm:
  config:
    engine_backend: vllm
    engine_config:
      max_num_seqs: 16
      max_num_batched_tokens: 8192
      max_model_len: 32768
      gpu_memory_utilization: 0.90
      enable_prefix_caching: true
      enable_chunked_prefill: true
      dtype: auto
      trust_remote_code: true
```

**TensorRT-LLM:**

```yaml
bis_llm:
  config:
    engine_backend: trtllm
    engine_config:
      backend: pytorch
      max_batch_size: 16
      max_num_tokens: 8192
      max_seq_len: 32768
      enable_chunked_prefill: true
      kv_cache_config:
        free_gpu_memory_fraction: 0.90
        enable_block_reuse: true
```

## Model and weights

- `checkpoint_name` (required): HF repo ID (or mounted path) of the model checkpoint. BIS-LLM serves prequantized checkpoints directly — point this at an FP8 or FP4 checkpoint when you want quantization.
- `model_name` (required): the model identifier the engine loads.
- `served_model_name` (optional): the model name returned in API responses and accepted in the `model` field of requests.
- `model_path` / `model_path_for_tokenizer` (optional): local paths to the model and tokenizer when you mount weights with the top-level `weights` block. Point the tokenizer at a mounted path rather than a remote repo ID so the engine loads it locally:

```yaml
weights:
  - source: hf://Qwen/Qwen2.5-7B-Instruct
    mount_location: /models/qwen
bis_llm:
  config:
    model_path: /models/qwen
    model_path_for_tokenizer: /models/qwen
```

## Runtime settings

- `tensor_parallel_size` (number, default 1): number of GPUs for tensor parallelism. Set it to the GPU count in your `accelerator`.
- `engine_config` (object): engine runtime settings in the active engine's native field names (see above).
- `tokenizer_limit_length` (number): maximum token length the tokenizer accepts for a request.
- `additional_environment_variables` (object): per-component env vars passed into the serving pod, keyed by component (e.g. `Worker`):

```yaml
bis_llm:
  config:
    additional_environment_variables:
      Worker:
        VLLM_ALLOW_LONG_MAX_MODEL_LEN: "1"
```

## Autoscaling (token-based)

BIS-LLM autoscales on **in-flight tokens** instead of request concurrency. The deployment API rejects `concurrency_target` and `target_utilization_percentage`. Configure scaling with `target_in_flight_tokens` only.

```yaml
autoscaling_settings:
  min_replica: 1
  max_replica: 4
  autoscaling_window: 300   # seconds; 300 (5 min) is a good default
  scale_down_delay: 300     # seconds; 300-600 (5-10 min) works for most workloads

additional_autoscaling_config:
  metrics:
    - name: in_flight_tokens
      target: 40000
```

| Setting | What it controls |
| --- | --- |
| `min_replica` / `max_replica` | Replica bounds. **Scale-to-zero is not supported** — set `min_replica` to at least 1. Set `max_replica` to cap scale-up during cold starts. |
| `autoscaling_window` | Sliding window (seconds) used to average in-flight tokens before a scaling decision. Longer smooths spikes; shorter reacts faster. 300s is a reasonable default. |
| `scale_down_delay` | Seconds to wait before removing replicas after load drops. 300–600s works for most workloads. |
| `metrics.target` | Target in-flight tokens per replica. **The primary knob to tune.** |

### How in-flight tokens are counted

The Planner's load measure is the sum of two per-worker counts:

- **Prefill tokens:** uncached input tokens currently being processed across active requests. Tokens served from KV cache reuse do **not** count.
- **Decode tokens:** the full sequence length (input + tokens generated so far) for every request currently decoding.

This is why request count alone misses real load: a long-context decode with a 100K-token KV cache contributes 100K to the load measure even though it is "just one request." The total across the deployment roughly equals `active_requests × average_tokens_per_request`, which makes targets easy to derive from request-based intuition.

### Set target in-flight tokens

For most LLMs, a target in the **50,000 to 150,000** range is a sensible starting point. From there:

- **Lower target:** more replicas at a given load. More headroom, higher cost.
- **Higher target:** fewer replicas at a given load. Less headroom, lower cost.

Convert from a request-concurrency target directly:

```
target = concurrency_target × average_tokens_per_request
        ≈ concurrency_target × (avg_input_tokens + avg_output_tokens)
```

For a model averaging 4K input + 1K output tokens at a concurrency of 10: `target = 5,000 × 10 = 50,000`.

Once set, the autoscaler computes: `desired_replicas = avg_in_flight_tokens / target_in_flight_tokens`. Start conservatively and adjust based on observed latency.

### Graceful scale-down with `max_scale_down_rate`

By default the autoscaler removes up to **50% of replicas per step**. BIS-LLM deployments hold KV cache state on each worker — a sudden 50% drop means 50% loss of KV cache space, causing a wave of cache misses and TTFT spikes for cache-sensitive workloads (long shared system prompts, multi-turn conversations).

`max_scale_down_rate` caps the percentage of replicas removed per scale-down step, with a full `scale_down_delay` between steps. BIS-LLM defaults to **20% every 300 seconds**. Lower the rate or lengthen the delay to keep replicas (and their cache) around for more reuse; raise them to release capacity faster. Configure in the UI or the Management API.

### Known autoscaling issues (structural, not config mistakes)

- **Scale-up overshoot during rapid load increase.** Workers take time to start (model loading + warmup). Until they are healthy they aren't counted in the autoscaler's worker pool, so the Planner keeps seeing high per-worker load and requesting more replicas. By the time new workers are healthy, the deployment may be over-provisioned. **Mitigation:** set `max_replica` to cap the overshoot. Cold start time is the underlying constraint.
- **Scale-down thrashing and KV cache loss.** Aggressive or frequent scale-down forces full prefill on requests that would otherwise have hit cache (higher TTFT). **Mitigation:** keep `max_scale_down_rate` low (20% default) and `scale_down_delay` moderate (300–600s).

## Advanced features (Enterprise-gated)

Speculative decoding, KV-aware routing, and disaggregated serving are configured through their own blocks in `bis_llm.config`. To enable any of them, contact support@baseten.co.

### KV-aware routing

A stateful router runs in front of the BIS-LLM worker pool and maintains a real-time index of every worker's KV cache contents. For each request it tokenizes the prompt, scores each worker against the prompt's tokens, and returns the worker most likely to serve the request from cache, balanced against current worker load.

Settings live under `b10_routing_config`. Defaults match Model APIs and rarely need to change.

```yaml
bis_llm:
  config:
    b10_routing_config:
      router_queue_policy: fcfs           # or wspt
      router_overlap_score_weight: 3.5
      router_temperature: 0.05
```

- `router_queue_policy`: `fcfs` (first-come first-served + priority bumps; optimizes tail TTFT and fairness, default) or `wspt` (weighted shortest processing time; prioritizes cheaper requests, risks starving costly ones — use when avg TTFT matters more than tail).
- `router_overlap_score_weight` (default 3.5): bias toward cache hits vs load balance. Higher = more cache hits at the cost of balance.
- `router_temperature` (default 0.05): randomness in worker selection. Higher spreads load; lower concentrates hits.

**When to use:** KV-aware routing is on by default for BIS-LLM v3 deployments and pays off whenever prompts share prefixes — agent loops, chat with long system messages, RAG pipelines reusing retrieved context, code completion. Workloads with no prefix overlap see only the load-balancing benefit.

**Sticky sessions:** for dedicated deployments, pin related requests to the same replica by sending the `x-session-affinity` header with a consistent value across the group. This keeps the group's shared prefix resident in one replica's KV cache and raises `kv_cache_hit_rate`.

### Disaggregated serving

Splits prefill and decode into separate replica groups so a long prefill never blocks decode latency on other replicas. Each phase scales independently based on its own load.

```yaml
bis_llm:
  config:
    is_disaggregated: true
    b10_disagg_config:
      prefill_workers_per_replica: 1
      decode_workers_per_replica: 2
```

- `is_disaggregated` (required): must be `true` for `b10_disagg_config` to take effect.
- `prefill_workers_per_replica` / `decode_workers_per_replica` (required, integer >= 1): define a **replication unit** — the smallest independently scalable group. A `1:2` config means each unit has 1 prefill pod + 2 decode pods. The autoscaler scales the number of units, not individual pods.

The backend rejects: `is_disaggregated: false` with `b10_disagg_config` set, and `is_disaggregated: true` with either worker count missing or < 1.

**When to use:** mismatched prefill/decode resource profiles (long-context 128K+ models with compute-heavy prefills and memory-bound decodes); strict TTFT targets (isolating prefill prevents decode requests queuing behind long prompts); variable prompt lengths (mixed short/long workloads benefit more than uniform). For consistent prompt lengths or workloads where TTFT isn't a bottleneck, aggregated serving is simpler and sufficient.

### Speculative decoding

Draft several future tokens cheaply, then verify them against the main model in a single forward pass. Accepted tokens advance the output; rejected tokens are discarded and the model resumes autoregressive decoding from the last accepted token.

This is a different system from v1 [lookahead decoding](https://docs.baseten.co/engines/engine-builder-llm/lookahead-decoding) (configured with `trt_llm.build.speculator`). The v2 stack rejects `trt_llm.build.speculator`; use `speculative_config` instead.

Set `speculative_config` in `bis_llm.config`. Required fields depend on `decoding_type`:

- `decoding_type` (required, case-insensitive): `Eagle`, `MTP`, or `NGram`.
- `speculative_model_dir` (required for `Eagle`): path to the Eagle head weights directory. BDN mirrors this as a standalone weight volume, separate from the main model weights.
- `num_nextn_predict_layers` (required for `MTP`): number of next-token prediction layers in the model architecture.
- `max_draft_len` (optional): max tokens the draft proposes per step. Raise for more aggressive speculation; lower if acceptance is poor.
- `eagle3_one_model` (optional, `Eagle` only): run the Eagle3 draft head and the target model as a single fused model. Set to `true` for Eagle3 checkpoints that support it.

**Eagle:**

```yaml
bis_llm:
  config:
    speculative_config:
      decoding_type: Eagle
      speculative_model_dir: /models/eagle
      max_draft_len: 3
      eagle3_one_model: true
```

**MTP** (DeepSeek-V3 and other models with MTP heads):

```yaml
bis_llm:
  config:
    speculative_config:
      decoding_type: MTP
      num_nextn_predict_layers: 1
```

**NGram** (no draft model; high-throughput workloads where any acceleration helps):

```yaml
bis_llm:
  config:
    speculative_config:
      decoding_type: NGram
```

| Type | How it works | Best for |
| --- | --- | --- |
| `Eagle` | Separate Eagle head drafts tokens from a hidden-state representation. | Models with trained Eagle checkpoints. |
| `MTP` | The model's own multi-token-prediction layers draft multiple tokens per step. | Models with MTP heads built in (DeepSeek-V3). |
| `NGram` | N-gram automata predict tokens from pattern matching without model computation. | High-throughput workloads where latency matters more than acceptance rate. |

Pick by **model architecture, not preference**.

## Observability

BIS-LLM emits metrics from three components. Each has its own dashboard section. Fetch them via `baseten model deployment metrics` (see `baseten-cli.md`).

| Domain | Metric prefix | Page |
| --- | --- | --- |
| Autoscaler decisions | `autoscaler_*` | Autoscaling engines → Monitoring |
| Router and KV cache | `kv_cache_*` | KV-aware routing → Monitoring |
| Engine and request | engine-level (below) | This page |

### Engine-level metrics (every BIS-LLM deployment)

| Metric | What it measures |
| --- | --- |
| `tps_per_request` | Tokens per second per request. **Start here** to confirm replicas handle load as expected. |
| `input_tokens` / `output_tokens` | Total token throughput across the deployment. |
| `input_tokens_per_request` / `output_tokens_per_request` | Per-request token averages. |
| `concurrent_requests` | Currently in-flight request count. |
| `speculation_rate` | Draft-token acceptance rate when speculative decoding is active. High rates indicate the draft model is well-aligned. |
| `cpu_usage` / `memory_usage` / `gpu_usage` / `gpu_memory_usage` | Resource utilization per replica. |
| `replica_count_by_status` | Replica counts grouped by lifecycle status. |

If you run Enterprise features, add `kv_cache_hit_rate` (KV-aware routing, router domain) or `speculation_rate` (Eagle/MTP) next.

`speculation_rate` guidance:

- **Above 80%:** draft is well-aligned; speculation is effective.
- **40–80%:** some rejections. Consider tuning the draft model or switching decoding types.
- **Below 40%:** speculation likely costs more than it saves. Disable it or reduce draft length.

### Autoscaler metrics

Fetch with `baseten model deployment metrics --metric <name>`. Start with `autoscaler_in_flight_tokens` to see what the autoscaler is currently observing, then reach for the averaged and policy-applied metrics when tuning.

| Metric | Type | What it measures |
| --- | --- | --- |
| `autoscaler_in_flight_tokens` | Gauge | Instantaneous in-flight tokens across all workers. Primary product-visible metric. |
| `autoscaler_avg_in_flight_tokens` | Gauge | Sliding-window average used for scaling decisions. |
| `autoscaler_avg_num_requests` | Gauge | Sliding-window average request count across all workers. |
| `autoscaler_avg_num_workers` | Gauge | Sliding-window average healthy worker count. The denominator for per-worker load. |
| `autoscaler_desired_scale` | Gauge | Raw desired scale from the token-based autoscaler, before policy. |
| `autoscaler_policy_desired_scale` | Gauge | Desired scale after policy is applied. |
| `autoscaler_rounded_desired_scale` | Gauge | Final integer scale sent to Kubernetes. |

What to watch:

- `autoscaler_rounded_desired_scale` pinned at `max_replica` for extended periods → capacity-constrained. Raise the cap or the target.
- Large persistent gap between `autoscaler_desired_scale` and actual replica count → scaling is too slow in one direction. Tune `autoscaling_window` for scale-up or `max_scale_down_rate` / `scale_down_delay` for scale-down.

## Complete configuration examples

### Qwen2.5-7B on vLLM (H100)

```yaml config.yaml
model_name: qwen2-5-7b
resources:
  accelerator: H100:1
  use_gpu: true
weights:
  - source: hf://Qwen/Qwen2.5-7B-Instruct
    mount_location: /models/qwen
bis_llm:
  config:
    engine_backend: vllm
    checkpoint_name: Qwen/Qwen2.5-7B-Instruct
    model_name: Qwen/Qwen2.5-7B-Instruct
    served_model_name: Qwen/Qwen2.5-7B-Instruct
    model_path: /models/qwen
    model_path_for_tokenizer: /models/qwen
    tensor_parallel_size: 1
    engine_config:
      max_num_seqs: 16
      max_num_batched_tokens: 8192
      max_model_len: 32768
      gpu_memory_utilization: 0.90
      enable_prefix_caching: true
      enable_chunked_prefill: true
      dtype: auto
      trust_remote_code: true
  additional_autoscaling_config:
    metrics:
      - name: in_flight_tokens
        target: 16000
```

### DeepSeek V3.2 on vLLM (H200 × 4)

```yaml config.yaml
model_name: deepseek-v3-2
resources:
  accelerator: H200:4
  use_gpu: true
bis_llm:
  config:
    engine_backend: vllm
    checkpoint_name: nvidia/DeepSeek-V3.2-NVFP4
    model_name: deepseek-ai/DeepSeek-V3.2
    tensor_parallel_size: 4
    engine_config:
      max_num_seqs: 64
      max_num_batched_tokens: 16384
      max_model_len: 20480
      gpu_memory_utilization: 0.92
      enable_prefix_caching: true
      enable_chunked_prefill: true
      dtype: auto
      trust_remote_code: true
  additional_autoscaling_config:
    metrics:
      - name: in_flight_tokens
        target: 30000
```

## Migrate from Engine-Builder-LLM (v1)

The Engine-Builder `trt_llm` build schema has a v2 (`inference_stack: v2`) that moves runtime fields out of `build:`, renames `tensor_parallel_count` to `tensor_parallel_size`, and drops fields v2 handles automatically (`plugin_configuration`, `base_model`). See <https://docs.baseten.co/engines/bis-llm/migrate-from-v1> for the field-by-field mapping, semantic changes, and validation errors you might see during cutover.

## Gotchas

- **BIS-LLM is Enterprise-gated** — KV-aware routing, disaggregated serving, and Eagle/MTP speculation each require enablement. NGram speculation is generally available.
- **`engine_config` field names are engine-native.** vLLM ≠ TRT-LLM names (see above). Mixing them fails fast with a clear error.
- **BIS-LLM autoscales on in-flight tokens, not request concurrency.** `concurrency_target` and `target_utilization_percentage` are rejected. Use `target_in_flight_tokens` (50K–150K starting range).
- **Scale-to-zero is not supported.** `min_replica` >= 1.
- **KV cache erodes on scale-down.** Keep `max_scale_down_rate` low (20% default) and `scale_down_delay` moderate (300–600s) for cache-sensitive workloads.
- **`bis_llm.version`** — omit unless your Baseten representative gives you a specific value.
- **Gated HF repos** need a secret (`hf_access_token` is the conventional name) configured in the workspace.

## Further reading

- BIS-LLM overview: <https://docs.baseten.co/engines/bis-llm>
- BIS-LLM config reference: <https://docs.baseten.co/engines/bis-llm/bis-llm-config>
- Advanced features: <https://docs.baseten.co/engines/bis-llm/advanced-features>
- Autoscaling BIS-LLM: <https://docs.baseten.co/engines/performance-concepts/autoscaling-engines#bis-llm>
- Migrate from v1: <https://docs.baseten.co/engines/bis-llm/migrate-from-v1>
- Truss config schema (authoritative): <https://github.com/basetenlabs/truss/blob/main/truss/config.schema.json>
- Push/iterate: see `truss-push.md` and `baseten-cli.md`.
