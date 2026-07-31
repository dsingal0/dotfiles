#!/bin/bash
set -euo pipefail

CLONE_DIR="${CLONE_DIR:-$HOME/repos}"

mkdir -p "$CLONE_DIR"

REPOS=(
  "git@github.com:basetenlabs/baseten.git:baseten"
  "git@github.com:basetenlabs/truss.git:truss"
  "git@github.com:basetenlabs/dynamo.git:baseten_dynamo"
  "git@github.com:dsingal0/vllm.git:dsingal_vllm"
  "https://github.com/NVIDIA/TensorRT-LLM.git:TensorRT-LLM"
  "https://github.com/sgl-project/sglang.git:sglang"
  "https://github.com/vllm-project/vllm.git:vllm"
  "git@github.com:basetenlabs/vllm.git:baseten_vllm"
  "git@github.com:basetenlabs/sglang.git:baseten_sglang"
  "git@github.com:basetenlabs/trt-llm.git:baseten_trt-llm"
)

clone_one() {
  local url="$1"
  local dir="$2"
  local target="$CLONE_DIR/$dir"

  if [ -d "$target/.git" ]; then
    echo "Already cloned: $target"
  else
    echo "Cloning (shallow) $url -> $target"
    git clone --depth 1 "$url" "$target"
  fi
}

unshallow_one() {
  local dir="$1"
  local target="$CLONE_DIR/$dir"

  if [ -d "$target/.git" ]; then
    echo "Unshallowing $target"
    git -C "$target" fetch --unshallow
  fi
}

pids=()

for entry in "${REPOS[@]}"; do
  url="${entry%:*}"
  dir="${entry##*:}"
  clone_one "$url" "$dir" &
  pids+=($!)
done

for pid in "${pids[@]}"; do
  wait "$pid"
done

echo "All shallow clones complete. Unshallowing..."

pids=()
for entry in "${REPOS[@]}"; do
  dir="${entry##*:}"
  unshallow_one "$dir" &
  pids+=($!)
done

for pid in "${pids[@]}"; do
  wait "$pid"
done

echo "Done!"
