---
name: build-vllm-from-source
description: Build vLLM Docker images from a GitHub PR branch, with optional precompiled kernel acceleration. Use when you need to test an unreviewed or unmerged PR, or build a custom vLLM image.
---

# Build vLLM from Source

## Overview

Build a `vllm-openai` Docker image from any vLLM PR or branch.

## Workflow

### 1. Identify the PR or branch

You'll typically have a PR number like `#43447`, a branch name, or a commit hash.

If it's a PR, fetch it:

```bash
git fetch origin pull/<PR_NUMBER>/head:pr-<PR_NUMBER>
git checkout pr-<PR_NUMBER>
```

If it's a fork branch, add the fork remote:
```bash
git remote add <fork_name> https://github.com/<user>/vllm.git
git fetch <fork_name> <branch_name>
git checkout <fork_name>/<branch_name>
```

### 2. Find the merge base for precompiled kernels (optional but recommended)

Precompiled wheels exist for commits on `main`. Use the merge base to avoid recompiling CUDA kernels:

```bash
MERGE_BASE=$(git merge-base HEAD main)
echo "Merge base: $MERGE_BASE"
```

This commit is passed as `VLLM_MERGE_BASE_COMMIT` below.

> If you want full compilation (no precompiled wheels), drop the `VLLM_USE_PRECOMPILED` and `VLLM_MERGE_BASE_COMMIT` build args.

### 3. Build the Docker image

```bash
DOCKER_BUILDKIT=1 docker build --target vllm-openai \
  --build-arg max_jobs=64 \
  --build-arg RUN_WHEEL_CHECK=false \
  --build-arg nvcc_threads=8 \
  --build-arg VLLM_USE_PRECOMPILED="1" \
  --build-arg VLLM_MERGE_BASE_COMMIT="${MERGE_BASE}" \
  --progress plain \
  -f docker/Dockerfile \
  -t vllm-openai:pr-<PR_NUMBER> .
```

### 4. Verify the image

```bash
docker images vllm-openai:pr-<PR_NUMBER>
# Expected output: ~30GB+ image
```

## Build Arguments Reference

| Arg | Default | Description |
|-----|---------|-------------|
| `max_jobs` | (varies) | Parallel build jobs for `make` |
| `RUN_WHEEL_CHECK` | `true` | Validate the built wheel; set to `false` to skip |
| `nvcc_threads` | (varies) | Parallel NVCC threads per compilation unit |
| `VLLM_USE_PRECOMPILED` | `""` | Set to `"1"` to download precompiled CUDA kernel wheels |
| `VLLM_MERGE_BASE_COMMIT` | `""` | Commit hash for the precompiled wheel; must be a main-branch commit |
| `SCCACHE_BUCKET_NAME` | (unset) | S3 bucket for sccache (internal acceleration) |

## Notes

- The build produces a ~31GB image. Ensure sufficient disk space.
- Build time is ~15-45 min with precompiled kernels, or 1-2+ hours without.
- The image is self-contained and tagged for immediate use with `vllm serve`.
