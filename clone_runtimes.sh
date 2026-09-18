#!/bin/bash
# clone_runtimes.sh - clone the Baseten/vLLM/TensorRT-LLM repos into ~/repos,
# in parallel. Already-cloned repos are unshallowed (or skipped if full).
set -euo pipefail

CLONE_DIR="${CLONE_DIR:-$HOME/repos}"
mkdir -p "$CLONE_DIR"

REPOS=(
  "git@github.com:basetenlabs/baseten.git:baseten"
  "git@github.com:basetenlabs/truss.git:truss"
  "git@github.com:basetenlabs/dynamo.git:baseten_dynamo"
  "git@github.com:basetenlabs/bei.git:bei"
  "git@github.com:dsingal0/vllm.git:dsingal_vllm"
  "git@github.com:dsingal0/async_work_reports.git:async_work_reports"
  "git@github.com:basetenlabs/mirendil-rollout.git:mirendil-rollout"
  "https://github.com/NVIDIA/TensorRT-LLM.git:TensorRT-LLM"
  "https://github.com/sgl-project/sglang.git:sglang"
  "https://github.com/vllm-project/vllm.git:vllm"
  "git@github.com:basetenlabs/vllm.git:baseten_vllm"
  "git@github.com:basetenlabs/sglang.git:baseten_sglang"
  "git@github.com:basetenlabs/trt-llm.git:baseten_trt-llm"
)

clone_one() {
  local url="$1" target="$CLONE_DIR/$2"
  if [ -d "$target/.git" ]; then
    if git -C "$target" rev-parse --is-shallow-repository 2>/dev/null | grep -q true; then
      echo "Unshallowing $target"; git -C "$target" fetch --unshallow
    else
      echo "Already cloned: $target"
    fi
    return
  fi
  # A full clone lands the same history as shallow-clone + fetch --unshallow.
  echo "Cloning $url -> $target"; git clone "$url" "$target"
}

for entry in "${REPOS[@]}"; do
  clone_one "${entry%:*}" "${entry##*:}" &
done
wait
echo "Done!"
