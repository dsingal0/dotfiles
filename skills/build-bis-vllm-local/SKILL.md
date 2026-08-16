---
name: build-bis-vllm-local
description: Build a BIS vLLM Dynamo image locally for linux/amd64 from the newest vLLM main commit that already has a vLLM CI postmerge amd64 image. Use when iterating on vLLM BIS, CAR, DSv4 Flash, local docker_build, or when the user wants a local image instead of dynamo-push / Docker Hub.
---

# Build BIS vLLM locally (amd64)

Iterate locally. Do not `gh workflow run dynamo-push.yml` and do not `docker push` unless the user explicitly asks to publish a final customer image.

## Layout

All commands run from `mp/baseten_dynamo/cache_aware_routing` in the baseten monorepo.

| Pin | File |
| --- | --- |
| Engine SHA + Dynamo none image | `versions/vllm.env` |
| Overlay Dockerfile | `docker/gpu.vllm.Dockerfile` |
| Patch manifest | `docker/bis_build_info.json` |
| Patch files | `src/*.patch` |

Tag shape: `baseten/dynamo-cache-aware-routing:vllm-<ENGINE_SHA>-<DYNAMO_SHA>-<GIT_SHA>`

Print it: `make -s print-DYNAMO_IMAGE_GPU DYNAMO_VARIANT=vllm`

## Steps

1. **Pick ENGINE_SHA** — newest `origin/main` commit that has an amd64 postmerge image:

   ```bash
   python3 ~/dotfiles/skills/build-bis-vllm-local/scripts/latest_amd64_sha.py
   ```

   That walks `vllm-project/vllm` `origin/main` and inspects
   `public.ecr.aws/q9t5s3a7/vllm-ci-postmerge-repo:<SHA>`.
   First hit is the pin. Tip of main with no image is skipped.

   Write `ENGINE_SHA` and `ENGINE_BASE_IMAGE` in `versions/vllm.env`.
   Leave `ENGINE_REGISTRY=auto`.

2. **Patches** — every file in `docker/bis_build_info.json` `patches[]` must exist under `src/` and be applied in `gpu.vllm.Dockerfile` as:

   ```
   COPY src/<name> /tmp/
   patch -d "$VLLM_PARENT" -p1 --fuzz 0 --input=/tmp/<name>
   rm /tmp/<name>
   ```

   Default DSv4 patch: `src/vllm_pr51318_c128a_metadata_packing.patch` (vllm#51318).
   Dry-run against the pinned SHA's `vllm/models/deepseek_v4/sparse_mla.py` before building.
   Drop a patch only after it is already in that ENGINE_SHA.

3. **Pull the no-framework Dynamo image** from `DYNAMO_IMAGE_BASE` in `versions/vllm.env` (today `baseten/dynamo-test:v1.2.0.dev.<DYNAMO_SHA>-none`). The Dockerfile copies `/opt/dynamo/wheelhouse` from it.

   ```bash
   docker pull "$DYNAMO_IMAGE_BASE"
   ```

4. **Build amd64 into the local store only:**

   ```bash
   make docker_build DYNAMO_VARIANT=vllm \
     DOCKER_BUILD_OUTPUT='type=docker' \
     PLATFORMS=linux/amd64
   ```

   Requires Docker Hub login (`make docker_login` / `~/.docker/config.json`).
   Log to `/tmp/vllm-bis-local-build.log` if the build is long.

5. **Done when** `docker image inspect $(make -s print-DYNAMO_IMAGE_GPU DYNAMO_VARIANT=vllm)` succeeds.

## Run after build

```bash
make docker_compose_upd_image \
  DYNAMO_VARIANT=vllm \
  DEPLOY_CONFIG=../deploy/customer_bis_deployments/nvidia/DeepSeek-V4-Flash-0731/config.yaml \
  DYNAMO_IMAGE_GPU=<printed-tag> \
  PRIMARY_DYNAMO_GPUS=0,1
```

`DEPLOY_CONFIG` + `docker_compose_up` (no `_image`) is a hard error — it would rebuild. Pass `DYNAMO_IMAGE_GPU` explicitly.

## Guards

- `PLATFORMS=linux/amd64` only. The Dynamo none image is often amd64-only; a multi-arch build fails with `no match for platform in manifest`.
- Do not retag/push intermediate iteration images.
- `build-vllm-from-source` is a different skill (upstream `vllm-openai` from a PR). This skill stacks CAR + Dynamo wheels on a vLLM CI postmerge base.
