---
name: build-bis-trtllm-local
description: Build a BIS TensorRT-LLM Dynamo image locally for linux/amd64 from a pulled TRT-LLM base image plus the no-framework Dynamo wheelhouse. Use when iterating on TRT-LLM BIS, CAR, DSpark, rc25, local docker_build, or when the user wants a local image instead of dynamo-push / Docker Hub.
---

# Build BIS TensorRT-LLM locally (amd64)

Iterate locally. Do not `gh workflow run dynamo-push.yml` and do not `docker push` unless the user explicitly asks to publish a final customer image.

## Layout

All commands run from `mp/baseten_dynamo/cache_aware_routing` in the baseten monorepo.

| Pin | File |
| --- | --- |
| Engine tag + Dynamo none image | `versions/trtllm.env` |
| Overlay Dockerfile | `docker/gpu.trtllm.Dockerfile` |
| Variant patches | `src/trtllm/*.patch` (if present) |
| rc25 DSpark guided patch | `src/tensorrt_llm_rc25_dspark_guided.patch` |
| Fleet patch (skipped when `.standalone`) | `src/tensorrt_llm.patch` |

Tag shape: `baseten/dynamo-cache-aware-routing:trtllm-<ENGINE_SHA>-<DYNAMO_SHA>-<GIT_SHA>`

Print it: `make -s print-DYNAMO_IMAGE_GPU DYNAMO_VARIANT=trtllm`

`versions/trtllm.env` is the stock NVIDIA rc25 path (`ENGINE_BASE_IMAGE=nvcr.io/nvidia/tensorrt-llm/release:<tag>`). `src/trtllm/.standalone` skips the Baseten `tensorrt_llm.patch`.

## Steps

1. **Confirm ENGINE_BASE_IMAGE** in `versions/trtllm.env`. Override only when the user names a different NGC / Baseten TRT-LLM tag.

2. **Pull both bases** (NGC login required for `nvcr.io`):

   ```bash
   source versions/trtllm.env
   docker pull "$ENGINE_BASE_IMAGE"
   docker pull "$DYNAMO_IMAGE_BASE"
   ```

   `DYNAMO_IMAGE_BASE` is the no-framework image (`baseten/dynamo-test:v*.dev.<DYNAMO_SHA>-none`). The Dockerfile copies `/opt/dynamo/wheelhouse` from it. Dynamo SHA for TRT-LLM may differ from the vLLM pin — use the one in `versions/trtllm.env`.

3. **Patches apply at image build**, not on the host. `gpu.trtllm.Dockerfile` runs `apply_patches.sh`, then the rc25 guided patch, then `tensorrt_llm.patch` unless `.standalone` is set. Dry-run a new patch against the files in the pulled engine image before baking it:

   ```bash
   docker run --rm --entrypoint bash "$ENGINE_BASE_IMAGE" -lc \
     'python3 -c "import tensorrt_llm,os; print(os.path.dirname(tensorrt_llm.__file__))"'
   ```

4. **Build amd64 into the local store only:**

   ```bash
   make docker_build DYNAMO_VARIANT=trtllm \
     DOCKER_BUILD_OUTPUT='type=docker' \
     PLATFORMS=linux/amd64
   ```

   Requires Docker Hub login (`make docker_login`). Log to `/tmp/trtllm-bis-local-build.log` if the build is long.

5. **Done when** `docker image inspect $(make -s print-DYNAMO_IMAGE_GPU DYNAMO_VARIANT=trtllm)` succeeds.

## Run after build

```bash
make docker_compose_upd_image \
  DYNAMO_VARIANT=trtllm \
  DEPLOY_CONFIG=../deploy/customer_bis_deployments/nvidia/DeepSeek-V4-Flash-0731-trtllm/config.yaml \
  DYNAMO_IMAGE_GPU=<printed-tag> \
  PRIMARY_DYNAMO_GPUS=0,1
```

`DEPLOY_CONFIG` + `docker_compose_up` (no `_image`) is a hard error. Pass `DYNAMO_IMAGE_GPU` explicitly.

## Guards

- `PLATFORMS=linux/amd64` only. The Dynamo none image is often amd64-only.
- Do not retag/push intermediate iteration images.
- Do not mix `versions/trtllm.env` with a vLLM `ENGINE_SHA`.
- `trtllm-laguna` is a different variant (`versions/trtllm-laguna.env`) — only use it when the user names Laguna.
