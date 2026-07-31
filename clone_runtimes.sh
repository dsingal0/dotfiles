#!/bin/bash
set -euo pipefail

CLONE_DIR="${CLONE_DIR:-$HOME/repos}"

clone() {
  local url="$1"
  local dir="$2"
  local target="$CLONE_DIR/$dir"

  if [ -d "$target/.git" ]; then
    echo "Already cloned: $target"
  else
    echo "Cloning $url -> $target"
    git clone "$url" "$target"
  fi
}

mkdir -p "$CLONE_DIR"

clone "git@github.com:basetenlabs/baseten.git"        "baseten"
clone "git@github.com:basetenlabs/truss.git"          "truss"
clone "git@github.com:basetenlabs/dynamo.git"         "baseten_dynamo"
clone "git@github.com:dsingal0/vllm.git"              "dsingal_vllm"
clone "https://github.com/NVIDIA/TensorRT-LLM.git"    "TensorRT-LLM"
clone "https://github.com/sgl-project/sglang.git"     "sglang"
clone "https://github.com/vllm-project/vllm.git"      "vllm"
clone "git@github.com:basetenlabs/vllm.git"           "baseten_vllm"
clone "git@github.com:basetenlabs/sglang.git"         "baseten_sglang"
clone "git@github.com:basetenlabs/trt-llm.git"        "baseten_trt-llm"

echo "Done!"
