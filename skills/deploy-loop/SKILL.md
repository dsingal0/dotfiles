---
name: deploy-loop
description: Iterative Baseten deploy -> check logs -> deactivate if errored -> fix -> redeploy cycle. Use when pushing or debugging a Truss/BIS model deployment.
---

# Baseten Deploy Loop

Iterative deploy -> check logs -> deactivate if errored -> fix -> redeploy cycle for Baseten models.

## Prerequisites

- `truss` CLI installed and configured (`.trussrc` with remotes)
- Baseten API key for the target org

## Loop Steps

1. **Deploy**: `truss push --remote <remote> --non-interactive <truss_dir>`
2. **Wait**: Sleep for model startup (varies by model size, ~60-90s for 7B, ~240-300s for large LLMs)
3. **Check logs**: `truss model-logs --remote <remote> --model-id <mid> --deployment-id <did> --since 5m --non-interactive`
4. **Classify state**:
   - **Ready**: Logs show "Started server process", "Application startup complete", "Uvicorn running"
   - **Errored**: Logs show "AssertionError", "Traceback", "ModuleNotFoundError", "unrecognized arguments", "Model terminated unexpectedly", or repeated "Health check FAILED"
   - **Still loading**: Logs show shard loading, autotuning, weight mirroring — wait longer
5. **If errored**: Deactivate the deployment via Baseten Management API, fix the config, redeploy
6. **If ready**: Test with a sample request (see Testing below)
7. **If still loading**: Go to step 2 with a shorter wait

## API Endpoints

### Base URL

All Management API requests go to `https://api.baseten.co/v1/...` (NOT `app.baseten.co`).

### Deactivating Errored Deployments

```bash
curl -s -X POST "https://api.baseten.co/v1/models/<model-id>/deployments/<deployment-id>/deactivate" \
  -H "Authorization: Api-Key <api_key>"
```

### Activating a Deployment

```bash
curl -s -X POST "https://api.baseten.co/v1/models/<model-id>/deployments/<deployment-id>/activate" \
  -H "Authorization: Api-Key <api_key>"
```

### Promoting to Production

```bash
curl -s -X POST "https://api.baseten.co/v1/models/<model-id>/deployments/<deployment-id>/promote" \
  -H "Authorization: Api-Key <api_key>"
```

### Listing Deployments

```bash
curl -s "https://api.baseten.co/v1/models/<model-id>/deployments" \
  -H "Authorization: Api-Key <api_key>" | python3 -c "
import sys,json
data = json.load(sys.stdin)
deps = data if isinstance(data, list) else data.get('deployments', data.get('data', []))
for d in deps:
    print(f'  {d.get(\"name\",\"?\")} | {d.get(\"id\",\"?\")}: {d.get(\"status\",\"?\")} env={d.get(\"environment\",\"\")}')
"
```

### Deleting a Model

```bash
curl -s -X DELETE "https://api.baseten.co/v1/models/<model-id>" \
  -H "Authorization: Api-Key <api_key>"
```

## Testing

### BIS LLM Endpoint Paths

BIS LLM deployments use a different path than traditional Truss models:

- **Production endpoint**: `https://model-<model-id>.api.baseten.co/sync/v1/chat/completions`
- **Deployment-scoped** (no promotion needed): `https://model-<model-id>.api.baseten.co/deployment/<deployment-id>/sync/v1/chat/completions`

Regular Truss models use `/predict`, not `/sync/v1/chat/completions`.

### Chat Completions Test Request

```bash
curl -s -w "\n%{http_code}" -X POST "https://model-<model-id>.api.baseten.co/deployment/<deployment-id>/sync/v1/chat/completions" \
  -H "Authorization: Api-Key <api_key>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "<served_model_name>",
    "messages": [{"role": "user", "content": "Say hello"}],
    "max_tokens": 50
  }'
```

### Multimodal (Image) Test Request

```bash
curl -s -w "\n%{http_code}" -X POST "https://model-<model-id>.api.baseten.co/deployment/<deployment-id>/sync/v1/chat/completions" \
  -H "Authorization: Api-Key <api_key>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "<served_model_name>",
    "messages": [{"role": "user", "content": [
      {"type": "text", "text": "Describe this image."},
      {"type": "image_url", "image_url": {"url": "https://multimedia-example-files.replicate.dev/error-message.350x210.has-text.jpg"}}
    ]}],
    "max_tokens": 200
  }'
```

**Note**: Some CDNs (e.g. Wikimedia) return 403 without a proper User-Agent. Use `https://multimedia-example-files.replicate.dev/...` URLs for testing instead.

## Checking Logs

```bash
# All logs
truss model-logs --remote <remote> --model-id <mid> --deployment-id <did> --since 5m --non-interactive

# Error-only
truss model-logs --remote <remote> --model-id <mid> --deployment-id <did> --since 5m --min-level error --non-interactive

# Filter for specific patterns
truss model-logs --remote <remote> --model-id <mid> --deployment-id <did> --since 5m --non-interactive | grep -i "error\|assert\|traceback\|failed\|ready\|terminated"

# Get root cause from traceback
truss model-logs --remote <remote> --model-id <mid> --deployment-id <did> --since 1m --non-interactive | grep -B10 "EngineGenerateError" | grep -i "Error\|attribute\|key\|value"
```

## Parallel Experiments

To test multiple configs without polluting the account with separate model IDs:
1. Use the same `model_name` in all config.yaml files (pushes as new deployments under the same model)
2. Use deployment-scoped URLs to test each variant without promoting
3. Deactivate failed variants after testing

## Common Issues and Fixes

| Error | Fix |
|-------|-----|
| `ModuleNotFoundError: No module named 'msgpack'` | Add `msgpack` to worker Dockerfile pip install |
| `unrecognized arguments: --foo` | Remove the flag from `vllm_extra_args` or find the structured config equivalent |
| `AssertionError` in `build_for_cudagraph_capture` (MLA) | Set `enforce_eager: true` in `engine_config` to disable CUDA graphs |
| `cudagraph_capture_sizes should contain at least one element` | Use `enforce_eager: true` instead of empty capture sizes |
| `unexpected_keyword_argument` for CompilationConfig | The field name doesn't exist in this vLLM version; use `enforce_eager: true` |
| `Unknown reasoning parser: kimi_k2` | Use `kimi25` instead of `kimi_k2` for reasoning_parser/tool_call_parser |
| `Invalid structural tag specification` + `KeyError: 'triggers'` | Remove `tool_call_parser` and `reasoning_parser` from config — the parser triggers structural tags the model doesn't support in this vLLM version |
| `HfRenderer object has no attribute '_mm_req_counter'` | vLLM v0.23.0 HfRenderer bug with native multimodal passthrough on certain models. Try `encoder_dynamo: true` instead, or use a separate encoder service via `encoder_url` |
| `Encoder request failed: no instances found` | `encoder_dynamo: true` requires a co-deployed encoder component. Use `encoder_url` pointing to a separate encoder model deployment instead, or `engine_native_passthrough: true` if the model's HfRenderer is compatible |
| 403 when fetching media | Use replicate.dev test URLs, or set proper User-Agent in encoder's HTTPConnection |
| 404 "Model not found" on `/v1/chat/completions` | BIS LLM uses `/sync/v1/chat/completions`, not `/v1/chat/completions` |
| `BIS-LLM only supports one model weight volume` | Keep `speculative_config` in config — it classifies eagle weights as speculative. Removing it causes the BIS platform to see two model weight volumes |
| Health check FAILED / Model terminated unexpectedly | Check full logs for root cause traceback |

## Config Patterns

### enforce_eager (disable CUDA graphs + torch.compile)
```yaml
engine_config:
  enforce_eager: true
```

### Speculative decoding
```yaml
speculative_config:
  decoding_type: Eagle
  speculative_model_dir: /models/eagle-model

engine_config:
  vllm_extra_args:
    - "--speculative-config"
    - '{"method": "eagle3", "model": "/models/eagle-model", "num_speculative_tokens": 3}'
```

### BIS LLM multimodal (engine native passthrough)
```yaml
b10_vision_config:
  enabled: true
  engine_native_passthrough: true
  max_images: 40
  max_videos: 1
  max_total_media_size_mb: 240
```

### BIS LLM multimodal (external encoder)
```yaml
b10_vision_config:
  enabled: true
  encoder_url: https://model-<encoder-model-id>.api.baseten.co/environments/production/predict
  max_images: 8
  max_videos: 1
  max_total_media_size_mb: 50
```

### KV cache dtype
```yaml
engine_config:
  vllm_extra_args:
    - "--kv-cache-dtype"
    - "fp8"
```

### limit_mm_per_prompt (pre-initialize multimodal processor)
```yaml
engine_config:
  vllm_extra_args:
    - "--limit-mm-per-prompt"
    - '{"image": 40}'
```
