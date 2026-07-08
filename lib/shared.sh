#!/usr/bin/env bash
# shared.sh - common logic sourced by both setup.sh (Linux) and brew-setup.sh (macOS).
#
# This file is NOT executable on its own; it must be sourced after SCRIPT_DIR is
# set, e.g.:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$SCRIPT_DIR/lib/shared.sh"
#
# It exposes two functions that deduplicate the opencode permission config and
# the Factory Baseten BYOK custom-models config previously inlined in both
# bootstrap scripts.

# Ensure ~/.config/opencode/opencode.json has permission: allow (merged with
# any existing keys, e.g. an mcp servers block set elsewhere).
configure_opencode_permission() {
  mkdir -p ~/.config/opencode
  python3 - << 'PYEOF'
import json, os

path = os.path.expanduser("~/.config/opencode/opencode.json")
try:
    with open(path, "r") as f:
        config = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    config = {}

config.setdefault("$schema", "https://opencode.ai/config.json")
config["permission"] = "allow"

with open(path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PYEOF
}

# Configure Factory custom models (Baseten BYOK).
#
# Reads BASETEN_API_KEY from the environment (callers source .env first).
# Skips with a warning if the key is unset. Idempotent: existing entries for the
# same model id are updated in place (api key refresh); new ones are appended.
configure_factory_models() {
  if [[ -z "${BASETEN_API_KEY:-}" ]]; then
    echo "WARNING: BASETEN_API_KEY is not set. Skipping Baseten model config."
    echo "         To enable: cp .env.example .env and fill in your key, or export BASETEN_API_KEY."
    return 0
  fi

  mkdir -p ~/.factory
  BASETEN_API_KEY="$BASETEN_API_KEY" python3 - << 'PYEOF'
import json, os

settings_path = os.path.expanduser("~/.factory/settings.json")
try:
    with open(settings_path, "r") as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

settings.setdefault("customModels", [])

api_key = os.environ["BASETEN_API_KEY"]

baseten_models = [
    {
        "model": "openai/gpt-oss-120b",
        "displayName": "GPT-OSS 120B [Baseten]",
        "baseUrl": "https://inference.baseten.co/v1",
        "apiKey": api_key,
        "provider": "generic-chat-completion-api",
        "maxOutputTokens": 8192,
        "noImageSupport": True
    },
    {
        "model": "zai-org/GLM-4.7",
        "displayName": "GLM 4.7 [Baseten]",
        "baseUrl": "https://inference.baseten.co/v1",
        "apiKey": api_key,
        "provider": "generic-chat-completion-api",
        "maxOutputTokens": 8192,
        "noImageSupport": True
    },
    {
        "model": "moonshotai/Kimi-K2.5",
        "displayName": "Kimi K2.5 [Baseten]",
        "baseUrl": "https://inference.baseten.co/v1",
        "apiKey": api_key,
        "provider": "generic-chat-completion-api",
        "maxOutputTokens": 8192,
        "noImageSupport": False
    },
    {
        "model": "zai-org/GLM-5",
        "displayName": "GLM 5 [Baseten]",
        "baseUrl": "https://inference.baseten.co/v1",
        "apiKey": api_key,
        "provider": "generic-chat-completion-api",
        "maxOutputTokens": 8192,
        "noImageSupport": True
    },
    {
        "model": "nvidia/Nemotron-120B-A12B",
        "displayName": "Nemotron Super [Baseten]",
        "baseUrl": "https://inference.baseten.co/v1",
        "apiKey": api_key,
        "provider": "generic-chat-completion-api",
        "maxOutputTokens": 8192,
        "noImageSupport": True
    },
    {
        "model": "zai-org/GLM-5.1",
        "displayName": "GLM 5.1 [Baseten]",
        "baseUrl": "https://inference.baseten.co/v1",
        "apiKey": api_key,
        "provider": "generic-chat-completion-api",
        "maxOutputTokens": 8192,
        "noImageSupport": True
    },
    {
        "model": "moonshotai/Kimi-K2.6",
        "displayName": "Kimi K2.6 [Baseten]",
        "baseUrl": "https://inference.baseten.co/v1",
        "apiKey": api_key,
        "provider": "generic-chat-completion-api",
        "maxOutputTokens": 8192,
        "noImageSupport": False
    },
    {
        "model": "deepseek-ai/DeepSeek-V4-Pro",
        "displayName": "DeepSeek V4 Pro [Baseten]",
        "baseUrl": "https://inference.baseten.co/v1",
        "apiKey": api_key,
        "provider": "generic-chat-completion-api",
        "maxOutputTokens": 8192,
        "noImageSupport": True
    },
    {
        "model": "nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B",
        "displayName": "Nemotron Ultra [Baseten]",
        "baseUrl": "https://inference.baseten.co/v1",
        "apiKey": api_key,
        "provider": "generic-chat-completion-api",
        "maxOutputTokens": 8192,
        "noImageSupport": True
    },
    {
        "model": "zai-org/GLM-5.2",
        "displayName": "GLM 5.2 [Baseten]",
        "baseUrl": "https://inference.baseten.co/v1",
        "apiKey": api_key,
        "provider": "generic-chat-completion-api",
        "maxOutputTokens": 8192,
        "noImageSupport": True
    },
    {
        "model": "moonshotai/Kimi-K2.7-Code",
        "displayName": "Kimi K2.7 Code [Baseten]",
        "baseUrl": "https://inference.baseten.co/v1",
        "apiKey": api_key,
        "provider": "generic-chat-completion-api",
        "maxOutputTokens": 8192,
        "noImageSupport": False
    },
    # {
    #     "model": "zai-org/GLM-5.2-1M",
    #     "displayName": "GLM 5.2 1M [Baseten]",
    #     "baseUrl": "https://inference.baseten.co/v1",
    #     "apiKey": api_key,
    #     "provider": "generic-chat-completion-api",
    #     "maxOutputTokens": 8192,
    #     "noImageSupport": True
    # }
]

existing = {m.get("model"): i for i, m in enumerate(settings["customModels"])}
for m in baseten_models:
    name = m["model"]
    if name in existing:
        settings["customModels"][existing[name]]["apiKey"] = api_key
    else:
        settings["customModels"].append(m)

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF
}

# Source the .env file in the repo root (if present) so BASETEN_API_KEY and
# FACTORY_API_KEY are available to the functions below. Pass the repo root as $1.
load_env_file() {
  local repo_dir="$1"
  if [[ -f "$repo_dir/.env" ]]; then
    set -a; source "$repo_dir/.env"; set +a
  fi
}

# Persist `export <VAR>=<value>` into shell rc files (~/.bashrc always;
# ~/.zshrc if it exists) inside a managed block so re-runs update the value
# instead of duplicating lines. New shells pick it up automatically; existing
# shells need `source ~/.bashrc` (or a new terminal) to see it. The value is
# single-quoted and embedded single quotes are escaped.
persist_export_to_rc() {
  local var="$1" value="$2"
  [[ -z "$value" ]] && return 0
  local rc_files=( "$HOME/.bashrc" )
  [[ -f "$HOME/.zshrc" ]] && rc_files+=( "$HOME/.zshrc" )
  for rc in "${rc_files[@]}"; do
    touch "$rc"
    VAR="$var" VALUE="$value" python3 - "$rc" << 'PYEOF'
import os, re, sys

path = sys.argv[1]
var = os.environ["VAR"]
value = os.environ["VALUE"]
open_m = "# >>> %s (managed by dotfiles setup) >>>" % var
close_m = "# <<< %s <<<" % var

try:
    with open(path) as f:
        content = f.read()
except FileNotFoundError:
    content = ""

escaped = value.replace("'", "'\\''")
block = "%s\nexport %s='%s'\n%s" % (open_m, var, escaped, close_m)
pat = re.compile(r"\n?" + re.escape(open_m) + r".*?" + re.escape(close_m) + r"\n?", re.DOTALL)
content = pat.sub("\n", content)
content = content.rstrip()
if content:
    content += "\n\n"
content += block + "\n"

with open(path, "w") as f:
    f.write(content)
PYEOF
  done
}

# One-shot Factory configuration shared by both bootstrap scripts:
#   1. load .env (BASETEN_API_KEY, FACTORY_API_KEY)
#   2. write Baseten BYOK custom models into ~/.factory/settings.json
#   3. persist FACTORY_API_KEY to shell rc files so the droid CLI can read it
#      from the environment in new (and re-sourced) shells.
# Pass the repo root as $1.
configure_factory() {
  local repo_dir="$1"
  load_env_file "$repo_dir"
  configure_factory_models
  if [[ -n "${FACTORY_API_KEY:-}" ]]; then
    persist_export_to_rc "FACTORY_API_KEY" "$FACTORY_API_KEY"
    echo "FACTORY_API_KEY persisted to shell rc files."
    echo "  New shells: available automatically."
    echo "  Existing shells: run 'source ~/.bashrc' (or open a new terminal)."
  else
    echo "NOTE: FACTORY_API_KEY is not set in .env; skipping shell rc export."
    echo "      droid will fall back to its OAuth auth file (~/.factory/auth.v2.file)."
  fi
}
