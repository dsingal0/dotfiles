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

# nvm node version dirs, if any. Empty when nvm isn't installed (brew-setup.sh
# uses Homebrew node). Safe under `set -u` — never expands an unbound NVM_DIR.
_nvm_node_version_dirs() {
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  [[ -d "$nvm_dir/versions/node" ]] || return 0
  local d
  for d in "$nvm_dir"/versions/node/*/; do
    [[ -d "$d" ]] && printf '%s\n' "$d"
  done
}

# Uninstall opencode (v1 opencode-ai -> `opencode`, v2 @opencode-ai/cli ->
# `opencode2`) from EVERY nvm node version directory, not just the currently
# active one. `npm uninstall -g` only touches the active node version, so
# stale copies can linger in other version dirs and shadow the fresh install on
# PATH. Also drops the old curl-installer copy (~/.opencode/bin). Idempotent.
# Works without nvm (Homebrew / system node): skips the version-dir loop.
uninstall_opencode_all_node_versions() {
  echo "Uninstalling opencode (v1 + stale copies)..."
  local node_dir bin_dir lib_dir
  while IFS= read -r node_dir; do
    [[ -n "$node_dir" ]] || continue
    bin_dir="$node_dir/bin"
    lib_dir="$node_dir/lib/node_modules"
    rm -f "$bin_dir/opencode" "$bin_dir/opencode2" 2>/dev/null || true
    rm -rf "$lib_dir/opencode-ai" "$lib_dir/@opencode-ai" 2>/dev/null || true
  done < <(_nvm_node_version_dirs)
  # Old curl installer (~/.opencode/bin/opencode) so the npm-managed binary is
  # the one on PATH.
  rm -f "$HOME/.opencode/bin/opencode" 2>/dev/null || true
  rmdir "$HOME/.opencode/bin" 2>/dev/null || true
  # Current npm prefix (Homebrew node, or the active nvm version). Idempotent.
  npm uninstall -g opencode-ai @opencode-ai/cli >/dev/null 2>&1 || true
}

# Fully uninstall oh-my-openagent (OmO) remnants — the v1-only orchestration
# plugin. Does NOT touch opencode v2's config or credentials (those live in
# ~/.config/opencode and ~/.local/share/opencode and belong to the running v2
# install). Idempotent.
uninstall_opencode_and_omo() {
  echo "Removing OmO (v1 orchestration plugin) remnants..."
  # Kill lingering processes.
  pkill -f "oh-my-open" 2>/dev/null || true

  # Package-manager copies of the plugin.
  npm uninstall -g oh-my-openagent oh-my-opencode 2>/dev/null || true

  # Old curl/bun installer copies.
  rm -rf "$HOME/.omo" "$HOME/.cache/oh-my-openagent" "$HOME/.config/oh-my-openagent" 2>/dev/null || true

  echo "  OmO remnants removed."
}

# Persist `export <VAR>=<value>` into shell rc files (~/.bashrc always;

# Ensure bun is available (oh-my-openagent's installer must run via `bunx`).
# Prefers Homebrew on macOS; falls back to the official bun installer script.
ensure_bun() {
  if command -v bun >/dev/null 2>&1; then
    return 0
  fi
  echo "Installing bun (oh-my-openagent requirement)..."
  if command -v brew >/dev/null 2>&1; then
    brew install oven-sh/bun/bun
  else
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
  fi
  command -v bun >/dev/null 2>&1 || {
    echo "WARNING: bun still not on PATH; oh-my-openagent install will be skipped." >&2
    return 1
  }
}

# Ensure ~/.config/opencode/opencode.json has a `baseten` OpenAI-compatible
# provider (https://inference.baseten.co/v1, the Baseten Model APIs) so opencode
# and OmO can run Baseten-hosted models (GLM-5.2, Kimi-K3, DeepSeek-V4-Pro, ...).
# Reads BASETEN_API_KEY from the environment (callers source .env first). Skips
# with a warning if the key is unset. Idempotent: merges with existing keys
# (permission, mcp, plugin) instead of overwriting them.
#
# The model list mirrors configure_factory_models below; opencode also
# auto-discovers whatever else the gateway serves via /v1/models.
# NOTE: the GLM-5.3 model chain is also pinned in configure_omod_slim_preset
# (oh-my-opencode-slim) — update both together when models change.
# auto-discovers whatever else the gateway serves via /v1/models.
configure_opencode_baseten_provider() {
  if [[ -z "${BASETEN_API_KEY:-}" ]]; then
    echo "WARNING: BASETEN_API_KEY is not set. Skipping opencode Baseten provider."
    echo "         To enable: cp .env.example .env and fill in your key, or export BASETEN_API_KEY."
    return 0
  fi

  mkdir -p ~/.config/opencode
  BASETEN_API_KEY="$BASETEN_API_KEY" python3 - << 'PYEOF'
import json, os

path = os.path.expanduser("~/.config/opencode/opencode.json")
try:
    with open(path) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}

cfg.setdefault("$schema", "https://opencode.ai/config.json")

api_key = os.environ["BASETEN_API_KEY"]
BASE_URL = "https://inference.baseten.co/v1"

cfg["provider"] = {
    "baseten": {
        "npm": "@ai-sdk/openai-compatible",
        "name": "Baseten",
        "options": {
            "baseURL": BASE_URL,
            "apiKey": api_key,
        },
        "models": {
            "deepseek-ai/DeepSeek-V4-Pro": {"name": "DeepSeek V4 Pro", "limit": {"context": 200000, "output": 262144}},
            "deepseek-ai/DeepSeek-V4-Flash-0731": {"name": "DeepSeek V4 Flash", "limit": {"context": 200000, "output": 262144}},
            "moonshotai/Kimi-K3": {"name": "Kimi K3", "limit": {"context": 200000, "output": 262144}},
            "nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B": {"name": "Nemotron Ultra", "limit": {"context": 200000, "output": 202800}},
            "zai-org/GLM-5.3": {"name": "GLM 5.3", "limit": {"context": 200000, "output": 262144}},
            "zai-org/GLM-5.3-Flash": {"name": "GLM 5.3 Flash", "limit": {"context": 200000, "output": 262144}},
            "zai-org/GLM-5.2": {"name": "GLM 5.2", "limit": {"context": 200000, "output": 262144}},
            "zai-org/GLM-5.2-Fast": {"name": "GLM 5.2 Fast", "limit": {"context": 200000, "output": 262144}},
        },
    },
    # OpenRouter (free-tier last resort). Dormant until OPENROUTER_API_KEY is
    # exported: opencode resolves {env:...} lazily, so the models are listed but
    # auth fails until the key exists.
    "openrouter": {
        "npm": "@ai-sdk/openrouter",
        "name": "OpenRouter",
        "options": {"apiKey": "{env:OPENROUTER_API_KEY}"},
        "models": {
            "deepseek/deepseek-chat:free": {"name": "DeepSeek Chat (free)"},
            "google/gemini-2.5-flash:free": {"name": "Gemini 2.5 Flash (free)"},
            "meta-llama/llama-3.3-70b-instruct:free": {"name": "Llama 3.3 70B (free)"},
            "qwen/qwen3-32b:free": {"name": "Qwen3 32B (free)"},
        },
    },
}

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
  echo "  opencode baseten provider configured (inference.baseten.co/v1)"
}

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

# Ensure runlayer MCP (https://baseten.runlayer.com/mcp) is configured in
# all three harnesses: opencode, droid, and cursor-cli. Idempotent.
configure_runlayer_mcp() {
  local url="https://baseten.runlayer.com/mcp"
  # opencode -> ~/.config/opencode/opencode.json (v1: mcp.<name> at top level)
  mkdir -p ~/.config/opencode
  python3 - << 'PYEOF'
import json, os
path = os.path.expanduser("~/.config/opencode/opencode.json")
try:
    with open(path) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}
cfg.setdefault("$schema", "https://opencode.ai/config.json")
cfg.setdefault("mcp", {})
cfg["mcp"]["runlayer"] = {"type": "remote", "url": "https://baseten.runlayer.com/mcp"}
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
  echo "  opencode runlayer MCP configured"

  # droid / Factory -> ~/.factory/mcp.json (mcpServers.<name> with type http)
  mkdir -p ~/.factory
  python3 - << 'PYEOF'
import json, os
path = os.path.expanduser("~/.factory/mcp.json")
try:
    with open(path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}
data.setdefault("mcpServers", {})
data["mcpServers"]["runlayer"] = {"type": "http", "url": "https://baseten.runlayer.com/mcp", "disabled": False}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
  echo "  droid runlayer MCP configured"

  # cursor CLI -> ~/.cursor/mcp.json (mcpServers.<name> with url)
  mkdir -p ~/.cursor
  python3 - << 'PYEOF'
import json, os
path = os.path.expanduser("~/.cursor/mcp.json")
try:
    with open(path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}
data.setdefault("mcpServers", {})
data["mcpServers"]["runlayer"] = {"url": "https://baseten.runlayer.com/mcp"}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
  echo "  cursor runlayer MCP configured"
}

# Symlink the repo's global opencode instructions into
# ~/.config/opencode/AGENTS.md so every project session picks up the same
# global rules (no /tmp, lowercase names, worktrees above the repo, Docker
# host networking). Idempotent: re-runs refresh the symlink.
# Pass the repo root as $1.
install_global_agents_md() {
  local repo_dir="$1"
  local src="$repo_dir/config/opencode/AGENTS.md"
  local dest="$HOME/.config/opencode/AGENTS.md"

  if [[ ! -f "$src" ]]; then
    echo "NOTE: no global AGENTS.md at $src; skipping."
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    # Preserve any hand-edited copy before taking over with the managed symlink.
    mv -f "$dest" "$dest.bak"
    echo "  backed up existing ~/.config/opencode/AGENTS.md -> AGENTS.md.bak"
  fi
  ln -sfn "$src" "$dest"
  echo "Global opencode AGENTS.md installed: $dest -> $src"
}

# Configure Factory custom models (Baseten BYOK).
#
# Reads BASETEN_API_KEY from the environment (callers source .env first).
# Skips with a warning if the key is unset. Idempotent: existing entries for the
# same model id are updated in place (api key refresh); new ones are appended;
# Baseten entries whose model is no longer served are pruned.
#
# The model list is synced with Baseten Model APIs
# (https://docs.baseten.co/inference/model-apis/overview); the live source of
# truth is `curl https://inference.baseten.co/v1/models -H "Authorization: Bearer $BASETEN_API_KEY"`.
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

BASE_URL = "https://inference.baseten.co/v1"

# Per-model reasoning_effort values, biased toward "high" (never xhigh/max),
# validated against each model's supported set. Supported sets are from
# https://docs.baseten.co/inference/model-apis/reasoning.
REASONING_EFFORT_SUPPORTED = {
    "deepseek-ai/DeepSeek-V4-Pro": {"none", "minimal", "low", "medium", "high", "xhigh", "max"},
    "moonshotai/Kimi-K3": {"none", "low", "high", "max"},
    "zai-org/GLM-5.2": {"none", "high", "max"},
    "zai-org/GLM-5.2-Fast": {"none", "high", "max"},
}
REASONING_EFFORT_VALUE = {
    "deepseek-ai/DeepSeek-V4-Pro": "high",
    "moonshotai/Kimi-K3": "high",
    "zai-org/GLM-5.2": "high",
    "zai-org/GLM-5.2-Fast": "high",
}
# Opt-in thinking models that need chat_template_args.enable_thinking to reason.
ENABLE_THINKING = {
    "nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B", "zai-org/GLM-5.2", "zai-org/GLM-5.2-Fast",
}

def baseten_model(model, display_name, no_image, max_output):
    extra_args = {}
    if model in REASONING_EFFORT_VALUE:
        value = REASONING_EFFORT_VALUE[model]
        supported = REASONING_EFFORT_SUPPORTED[model]
        if value not in supported:
            raise ValueError(
                "reasoning_effort %r not supported for %s (supported: %s)"
                % (value, model, sorted(supported)))
        extra_args["reasoning_effort"] = value
    if model in ENABLE_THINKING:
        extra_args["chat_template_args"] = {"enable_thinking": True}
    entry = {
        "model": model,
        "displayName": display_name,
        "baseUrl": BASE_URL,
        "apiKey": api_key,
        "provider": "generic-chat-completion-api",
        "maxOutputTokens": max_output,
        "noImageSupport": no_image,
    }
    if extra_args:
        entry["extraArgs"] = extra_args
    return entry

# Per-model max output mirrors /v1/models max_completion_tokens. extraArgs is
# derived from REASONING_EFFORT_VALUE / ENABLE_THINKING above.
baseten_models = [
    baseten_model("deepseek-ai/DeepSeek-V4-Pro", "DeepSeek V4 Pro [Baseten]", True, 262144),
    baseten_model("deepseek-ai/DeepSeek-V4-Flash-0731", "DeepSeek V4 Flash [Baseten]", True, 1048576),
    baseten_model("moonshotai/Kimi-K3", "Kimi K3 [Baseten]", False, 262144),
    baseten_model("nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B", "Nemotron Ultra [Baseten]", True, 202800),
    baseten_model("zai-org/GLM-5.2", "GLM 5.2 [Baseten]", True, 262144),
    baseten_model("zai-org/GLM-5.2-Fast", "GLM 5.2 Fast [Baseten]", True, 262144),
    # Served but intentionally skipped (too crippled/small for agentic coding):
    #   zai-org/GLM-5.2-1M      - max output capped at 5k
    #   inception/mercury-2     - 8k context
    #   sid/sid-1               - 32k context, 5k max output
]

# Prune Baseten-managed entries whose model is no longer served (e.g. GLM-5,
# GLM-5.1, Kimi-K2.5, Nemotron Super were dropped from the Model APIs).
wanted = {m["model"] for m in baseten_models}
kept = []
for m in settings["customModels"]:
    if m.get("baseUrl") == BASE_URL and m.get("model") not in wanted:
        print("  pruned no-longer-served Baseten model: %s" % m.get("model"))
        continue
    kept.append(m)
settings["customModels"] = kept

existing = {m.get("model"): i for i, m in enumerate(settings["customModels"])}
for m in baseten_models:
    name = m["model"]
    if name in existing:
        # Refresh the whole Baseten-managed entry (api key, output cap, args),
        # preserving droid-managed id/index.
        old = settings["customModels"][existing[name]]
        for k in ("id", "index"):
            if k in old:
                m[k] = old[k]
        settings["customModels"][existing[name]] = m
    else:
        print("  added Baseten model: %s" % name)
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
#   4. persist FACTORY_DISABLE_KEYRING=1 so droid stores auth in the portable
#      ~/.factory/auth.v2.file + auth.v2.key pair instead of the macOS login
#      keychain — this is what lets `devpod-bundle` carry droid auth to Linux.
# Pass the repo root as $1.
configure_factory() {
  local repo_dir="$1"
  load_env_file "$repo_dir"
  configure_factory_models
  persist_export_to_rc "FACTORY_DISABLE_KEYRING" "1"
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

# Configure the Cursor CLI (`agent`) for portable, file-based auth:
#   1. Persist AGENT_CLI_CREDENTIAL_STORE=file to shell rc files so cursor-agent
#      writes ~/.cursor/auth.json (macOS) / ~/.config/cursor/auth.json (Linux)
#      instead of the macOS Keychain — this is what makes `devpod-bundle` able to
#      carry the auth to Linux pods.
#   2. On Linux, copy ~/.cursor/auth.json -> ~/.config/cursor/auth.json (the path
#      cursor-agent reads there), so a bundle restored to ~/.cursor/auth.json works.
#   3. Keep sourcing ~/.cursor/env (CURSOR_API_KEY) for compatibility (legacy;
#      the current cursor-agent binary does not read CURSOR_API_KEY).
# Idempotent.
configure_cursor() {
  persist_export_to_rc "AGENT_CLI_CREDENTIAL_STORE" "file"

  local rc_files=( "$HOME/.bashrc" )
  [[ -f "$HOME/.zshrc" ]] && rc_files+=( "$HOME/.zshrc" )
  local source_line='[ -f "$HOME/.cursor/env" ] && . "$HOME/.cursor/env"'
  local rc
  for rc in "${rc_files[@]}"; do
    touch "$rc"
    RC_FILE="$rc" SOURCE_LINE="$source_line" python3 - "$rc" << 'PYEOF'
import os, re, sys
path = sys.argv[1]
line = os.environ["SOURCE_LINE"]
open_m = "# >>> cursor env (managed by dotfiles setup) >>>"
close_m = "# <<< cursor env <<<"
try:
    with open(path) as f:
        content = f.read()
except FileNotFoundError:
    content = ""
block = "%s\n%s\n%s" % (open_m, line, close_m)
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

  # Linux: cursor-agent reads ~/.config/cursor/auth.json; a restored bundle puts
  # the file at ~/.cursor/auth.json, so bridge the two.
  if [[ "$(uname -s)" != "Darwin" && -f "$HOME/.cursor/auth.json" ]]; then
    mkdir -p "$HOME/.config/cursor"
    cp -f "$HOME/.cursor/auth.json" "$HOME/.config/cursor/auth.json"
    chmod 600 "$HOME/.config/cursor/auth.json"
    echo "Cursor CLI: copied ~/.cursor/auth.json -> ~/.config/cursor/auth.json (Linux path)."
  fi

  if [[ -f "$HOME/.cursor/env" ]]; then
    echo "Cursor CLI: ~/.cursor/env present; new shells will export CURSOR_API_KEY."
  else
    echo "NOTE: ~/.cursor/env not found yet. Create it with:"
    echo "      printf 'export CURSOR_API_KEY=crsr_...\\n' > ~/.cursor/env && chmod 600 ~/.cursor/env"
    echo "      or restore it via: devpod-bundle --restore <bundle>.tar.gz"
  fi
}

# Symlink every skill under <repo>/skills/<name>/SKILL.md into each harness's
# global skills directory so droid, opencode, and cursor-cli all see the same
# personal skill set. Grok Build is included only when $2 is "true" (default),
# so brew-setup.sh installs grok skills while setup.sh skips them.
# Idempotent: re-runs refresh the symlinks.
#
# Targets (primary path per harness; avoids multi-scan duplicates):
#   Factory / droid  -> ~/.factory/skills/
#   OpenCode         -> ~/.config/opencode/skills/
#   Cursor CLI       -> ~/.cursor/skills/
#   xAI / Grok Build -> ~/.grok/skills/   (optional, see $2)
#
# Existing non-symlink directories are left alone (with a warning) so vendor
# or hand-installed skills are not clobbered.
# Pass the repo root as $1. Optionally pass "false" as $2 to skip grok.
# Pass a space-separated list of skill names as $3 to skip them (e.g. design
# skills that only brew-setup.sh installs).
install_shared_skills() {
  local repo_dir="$1"
  local include_grok="${2:-true}"
  local exclude_names="${3:-}"
  local skills_src="$repo_dir/skills"

  if [[ ! -d "$skills_src" ]]; then
    echo "NOTE: no skills/ directory at $skills_src; skipping skill install."
    return 0
  fi

  local targets=(
    "$HOME/.factory/skills"
    "$HOME/.config/opencode/skills"
    "$HOME/.cursor/skills"
  )
  if [[ "$include_grok" == "true" ]]; then
    targets+=("$HOME/.grok/skills")
  fi

  local target skill_dir name dest count=0
  for target in "${targets[@]}"; do
    mkdir -p "$target"
  done

  local harness_names="factory, opencode, cursor"
  [[ "$include_grok" == "true" ]] && harness_names+=", grok"

  echo "Installing shared skills from $skills_src ..."
  for skill_dir in "$skills_src"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_dir="${skill_dir%/}"
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    name="$(basename "$skill_dir")"

    if [[ -n "$exclude_names" && " $exclude_names " == *" $name "* ]]; then
      for target in "${targets[@]}"; do
        dest="$target/$name"
        if [[ -L "$dest" ]]; then
          rm -f "$dest"
          echo "  removed excluded skill: $dest"
        elif [[ -e "$dest" ]]; then
          echo "  WARNING: $dest exists and is not a symlink; leaving it alone."
        fi
      done
      echo "  skipped $name (excluded)"
      continue
    fi

    for target in "${targets[@]}"; do
      dest="$target/$name"
      if [[ -e "$dest" && ! -L "$dest" ]]; then
        echo "  WARNING: $dest exists and is not a symlink; leaving it alone."
        continue
      fi
      ln -sfn "$skill_dir" "$dest"
    done
    echo "  linked $name"
    count=$((count + 1))
  done

  echo "Shared skills installed: $count skill(s) -> $harness_names."
}

# Remove third-party skills from packs this machine should not have (e.g.
# expo/eas and design skills on Linux dev pods). Skill names are read from the
# skills CLI's global lock file (~/.agents/.skill-lock.json), which records the
# source repo for each installed skill, so removal is exact even when two packs
# ship a skill with the same name (e.g. `prototype` in both mattpocock and
# emilkowalski). Removal goes through `skills remove` so the lock file and the
# ~/.agents/skills canonical store stay consistent.
#
# Pass the pack sources to remove as $@ (e.g. "expo/skills" "emilkowalski/skills").
# Idempotent: missing skills are a no-op.
cleanup_excluded_skill_packs() {
  local sources=("$@")
  [[ ${#sources[@]} -gt 0 ]] || return 0

  local lock="$HOME/.agents/.skill-lock.json"
  [[ -f "$lock" ]] || return 0

  local -a names=()
  local n
  while IFS= read -r n; do
    [[ -n "$n" ]] && names+=("$n")
  done < <(python3 - "$lock" "${sources[@]}" << 'PYEOF'
import json, sys
lock_path = sys.argv[1]
sources = set(sys.argv[2:])
try:
    with open(lock_path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    sys.exit(0)
for name in sorted(data.get("skills", {})):
    if data["skills"][name].get("source") in sources:
        print(name)
PYEOF
)

  if [[ ${#names[@]} -eq 0 ]]; then
    echo "  no excluded pack skills installed; nothing to remove."
    return 0
  fi

  echo "Removing excluded pack skills: ${names[*]}"
  # NOTE: skill names must precede the -a flags; the skills CLI's remove parser
  # greedily consumes every non-flag arg after -a as an agent name.
    npx --yes skills@latest remove -g -y \
      "${names[@]}" \
      -a universal -a droid -a opencode -a cursor \
      || echo "WARNING: skill removal reported errors (continuing)."
}

# Install third-party skill packs globally via the skills.sh CLI (npx skills).
# Idempotent: re-runs refresh to latest from each source.
#
# Packs:
#   https://github.com/mattpocock/skills
#   https://github.com/expo/skills            (opt-in, see $2)
#   https://github.com/emilkowalski/skills    (opt-in, see $1)
#
# The baseten skill used to come from https://github.com/basetenlabs/baseten-skills
# but that pack is out of date and token-inefficient. It now lives as a static,
# pruned, BIS-focused copy in this repo under skills/baseten/ and is installed
# by install_shared_skills (same as the other personal skills). The stale
# third-party install is cleaned up by cleanup_stale_baseten_skill below.
#
# Agents are listed explicitly rather than --agent '*': Eve and PromptScript
# do not support global skill installation and would otherwise emit failures.
# `universal` covers ~/.agents/skills (also picked up by Grok Build, etc.).
#
# Pass "true" as $1 to also install the emilkowalski/skills pack
# (brew-setup.sh on macOS); setup.sh (Linux dev pods) skips it.
# Pass "false" as $2 to skip the expo/skills pack (Expo + EAS skills);
# setup.sh skips it, brew-setup.sh keeps it (default true).
#
# Requires node/npx (installed earlier by both bootstrap scripts).
install_skill_packages() {
  local include_emilkowalski="${1:-false}"
  local include_expo="${2:-true}"

  if ! command -v npx >/dev/null 2>&1; then
    echo "WARNING: npx not found; skipping third-party skill packages."
    return 0
  fi

  # Remove skills from packs this machine should not have (e.g. expo/eas and
  # design skills on Linux dev pods) before installing the included packs.
  local -a excluded_sources=()
  [[ "$include_expo" == "true" ]] || excluded_sources+=("expo/skills")
  [[ "$include_emilkowalski" == "true" ]] || excluded_sources+=("emilkowalski/skills")
  if [[ ${#excluded_sources[@]} -gt 0 ]]; then
    cleanup_excluded_skill_packs "${excluded_sources[@]}"
  fi

  local packs=(
    "mattpocock/skills"
  )
  if [[ "$include_expo" == "true" ]]; then
    packs+=("expo/skills")
  fi
  if [[ "$include_emilkowalski" == "true" ]]; then
    packs+=("emilkowalski/skills")
  fi
  # Harnesses we install in bootstrap + common neighbors. Skip eve / promptscript.
  local agents=(
    universal
    droid
    opencode
    cursor
  )
  local agent_args=()
  local a
  for a in "${agents[@]}"; do
    agent_args+=(-a "$a")
  done

  local pack
  for pack in "${packs[@]}"; do
    echo "Installing skill pack: $pack (global)..."
    # --full-depth: mattpocock nests skills under engineering/productivity/etc.
    npx --yes skills@latest add "$pack" -g -y --skill '*' --full-depth \
      "${agent_args[@]}" \
      || echo "WARNING: skill pack install reported errors for $pack (continuing)."
  done

  # Remove stale agent skill dirs left by a previous `--agent '*'` run.
  cleanup_stale_skill_dirs
}

# Remove dotdirs in $HOME whose entire contents are symlinks pointing into
# ~/.agents/skills/. These dirs are created by a previous
# `npx skills add --agent '*'` run (now replaced by an explicit agents list)
# and only contain skill symlinks — no real config or data. Real agent dirs
# (.cursor, .grok, .factory, .opencode) have config files and are
# never touched. Idempotent.
cleanup_stale_skill_dirs() {
  python3 - << 'PYEOF'
import os, glob, shutil

home = os.path.expanduser("~")
removed = 0
for entry in sorted(glob.glob(os.path.join(home, ".*"))):
    name = os.path.basename(entry)
    if name in (".", "..") or not os.path.isdir(entry):
        continue
    has_real = False
    has_skill_links = False
    for root, dirs, files in os.walk(entry, followlinks=False):
        for f in files:
            full = os.path.join(root, f)
            if os.path.islink(full):
                tgt = os.readlink(full)
                if ".agents/skills" in tgt:
                    has_skill_links = True
                else:
                    has_real = True
            else:
                has_real = True
        for d in dirs:
            full = os.path.join(root, d)
            if os.path.islink(full) and ".agents/skills" not in os.readlink(full):
                has_real = True
        if has_real:
            break
    if has_skill_links and not has_real:
        shutil.rmtree(entry)
        print(f"  removed stale skill dir: {name}")
        removed += 1
print(f"Stale skill dirs removed: {removed}")
PYEOF
}

# Remove the stale third-party `baseten` skill (from basetenlabs/baseten-skills)
# at every agent skill location so install_shared_skills can symlink the
# repo's static, pruned, BIS-focused copy (skills/baseten/) in its place.
#
# Only removes real directories / files — never symlinks (so a re-run after the
# repo symlink exists is a no-op). Idempotent.
cleanup_stale_baseten_skill() {
  local locations=(
    "$HOME/.agents/skills/baseten"
    "$HOME/.factory/skills/baseten"
    "$HOME/.config/opencode/skills/baseten"
    "$HOME/.cursor/skills/baseten"
    "$HOME/.grok/skills/baseten"
  )
  local loc removed=0
  for loc in "${locations[@]}"; do
    if [[ -e "$loc" && ! -L "$loc" ]]; then
      rm -rf "$loc"
      echo "  removed stale third-party baseten skill: $loc"
      removed=$((removed + 1))
    fi
  done
  echo "Stale baseten skill entries removed: $removed"
}

# Install the Baseten CLI (https://github.com/basetenlabs/baseten-cli).
# Prefers Homebrew (macOS and Linuxbrew); falls back to the latest GitHub
# release tarball into ~/.local/bin.
install_baseten_cli() {
  echo "Installing baseten CLI..."
  if command -v brew >/dev/null 2>&1; then
    brew tap basetenlabs/baseten
    # Third-party taps may require an explicit trust step on newer Homebrew.
    brew trust basetenlabs/baseten 2>/dev/null || true
    brew install baseten
    baseten --version 2>/dev/null || baseten version 2>/dev/null || true
    return 0
  fi

  mkdir -p "$HOME/.local/bin"
  local os arch asset url tmp
  case "$(uname -s)" in
    Darwin) os="darwin" ;;
    Linux)  os="linux" ;;
    *)
      echo "WARNING: unsupported OS for baseten CLI binary install: $(uname -s)"
      return 0
      ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch="arm64" ;;
    x86_64|amd64)  arch="amd64" ;;
    *)
      echo "WARNING: unsupported arch for baseten CLI binary install: $(uname -m)"
      return 0
      ;;
  esac

  # Resolve latest release tag via GitHub API; skip with a warning if the
  # fetch fails rather than silently installing a stale pinned release.
  local tag
  tag="$(curl -fsSL https://api.github.com/repos/basetenlabs/baseten-cli/releases/latest \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["tag_name"])' 2>/dev/null \
    || true)"
  if [[ -z "$tag" ]]; then
    echo "WARNING: could not resolve the latest baseten-cli release tag; skipping baseten CLI install."
    return 0
  fi
  local ver="${tag#v}"
  asset="baseten_${ver}_${os}_${arch}.tar.gz"
  url="https://github.com/basetenlabs/baseten-cli/releases/download/${tag}/${asset}"

  tmp="$(mktemp -d)"
  echo "  downloading $url ..."
  if curl -fsSL "$url" | tar xz -C "$tmp" && [[ -f "$tmp/baseten" ]]; then
    install -m 755 "$tmp/baseten" "$HOME/.local/bin/baseten"
    export PATH="$HOME/.local/bin:$PATH"
    baseten --version 2>/dev/null || baseten version 2>/dev/null || true
  else
    echo "WARNING: failed to download/install baseten CLI from $url"
  fi
  rm -rf "$tmp"
}

# Ensure uv is available, create ~/venv if missing, and install/upgrade into
# that venv:
#   - truss          (Baseten model authoring / deploy-loop)
#   - magic-wormhole (file transfer, alongside croc)
# The wormhole CLI is symlinked into ~/.local/bin so it's on PATH without
# activating the venv.
ensure_venv() {
  echo "Ensuring ~/venv with truss and magic-wormhole..."
  # Common install locations for uv (curl installer + Homebrew).
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

  if ! command -v uv >/dev/null 2>&1; then
    echo "  uv not found; installing via astral.sh..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi

  if ! command -v uv >/dev/null 2>&1; then
    echo "WARNING: uv still not on PATH; cannot create ~/venv."
    return 0
  fi

  # Create only if missing; never clobber an existing venv.
  if [[ ! -x "$HOME/venv/bin/python" ]]; then
    uv venv "$HOME/venv"
  fi
  uv pip install --python "$HOME/venv/bin/python" --upgrade truss magic-wormhole
  if [[ -x "$HOME/venv/bin/truss" ]]; then
    echo "  truss: $("$HOME/venv/bin/truss" version 2>/dev/null || "$HOME/venv/bin/python" -c 'import truss; print(getattr(truss, "__version__", "installed"))')"
  fi
  if [[ -x "$HOME/venv/bin/wormhole" ]]; then
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$HOME/venv/bin/wormhole" "$HOME/.local/bin/wormhole"
    echo "  wormhole: $("$HOME/venv/bin/wormhole" --version 2>/dev/null || echo installed)"
  fi
  echo "  venv ready at $HOME/venv (activate with: source ~/venv/bin/activate)"
}

# Install croc (https://github.com/schollz/croc) for file transfer (replaces
# magic-wormhole). Prefers Homebrew; falls back to the latest GitHub release
# tarball into ~/.local/bin.
ensure_croc() {
  echo "Installing croc..."
  if command -v brew >/dev/null 2>&1; then
    brew install croc
    croc --version 2>/dev/null || true
    return 0
  fi

  mkdir -p "$HOME/.local/bin"
  local os arch asset url tmp
  case "$(uname -s)" in
    Darwin) os="macOS" ;;
    Linux)  os="Linux" ;;
    *)
      echo "WARNING: unsupported OS for croc binary install: $(uname -s)"
      return 0
      ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch="ARM64" ;;
    x86_64|amd64)  arch="64bit" ;;
    *)
      echo "WARNING: unsupported arch for croc binary install: $(uname -m)"
      return 0
      ;;
  esac

  # Resolve latest release tag via GitHub API; skip with a warning if the
  # fetch fails rather than silently installing a stale pinned release.
  local tag
  tag="$(curl -fsSL https://api.github.com/repos/schollz/croc/releases/latest \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["tag_name"])' 2>/dev/null \
    || true)"
  if [[ -z "$tag" ]]; then
    echo "WARNING: could not resolve the latest croc release tag; skipping croc install."
    return 0
  fi
  local ver="${tag#v}"
  asset="croc_v${ver}_${os}-${arch}.tar.gz"
  url="https://github.com/schollz/croc/releases/download/${tag}/${asset}"

  tmp="$(mktemp -d)"
  echo "  downloading $url ..."
  if curl -fsSL "$url" | tar xz -C "$tmp" && [[ -f "$tmp/croc" ]]; then
    install -m 755 "$tmp/croc" "$HOME/.local/bin/croc"
    export PATH="$HOME/.local/bin:$PATH"
    croc --version 2>/dev/null || true
  else
    echo "WARNING: failed to download/install croc from $url"
  fi
  rm -rf "$tmp"
}

# ============================================================================
# 2026-09 stack: opencode v2 (opencode2, @opencode-ai/cli beta channel) +
# oh-my-opencode-slim (agent orchestration plugin).
# ============================================================================

# Install/update opencode v2 (@opencode-ai/cli, bin `opencode2`) from the
# beta dist-tag — that is where v2 ships (the v1 line stays opencode-ai@latest).
# Installs into EVERY nvm node version dir + the current npm prefix so no
# stale copy shadows PATH.
install_opencode_v2() {
  echo "Installing opencode v2 (@opencode-ai/cli, beta channel)..."
  local node_dir bin_dir installed=0 current_bin="" skip_current=0
  if command -v npm >/dev/null 2>&1; then
    current_bin="$(dirname "$(command -v npm)")"
  fi
  _install_v2_into() {
    local bin_dir="$1"
    local attempt
    for attempt in 1 2 3; do
      if PATH="$bin_dir:$PATH" npm install -g @opencode-ai/cli@beta >/dev/null 2>&1 && \
         PATH="$bin_dir:$PATH" opencode2 --version >/dev/null 2>&1; then
        echo "  opencode2 ready: $bin_dir"
        return 0
      fi
      echo "Warning: opencode2 not runnable in $bin_dir (attempt $attempt/3); retrying..." >&2
      sleep 2
    done
    return 1
  }
  while IFS= read -r node_dir; do
    [[ -n "$node_dir" ]] || continue
    bin_dir="$node_dir/bin"
    [[ -n "$current_bin" && "$bin_dir" == "$current_bin" ]] && skip_current=1
    if _install_v2_into "$bin_dir"; then
      installed=$((installed + 1))
    fi
  done < <(_nvm_node_version_dirs)
  if [[ "$skip_current" -eq 0 && -n "$current_bin" ]]; then
    if _install_v2_into "$current_bin"; then
      installed=$((installed + 1))
    fi
  fi
  if [[ "$installed" -eq 0 ]]; then
    echo "WARNING: opencode v2 could not be installed (continuing)" >&2
    return 0
  fi
  # Alias `opencode` -> the v2 binary: slim's installer and other tooling look
  # for the `opencode` name; v2 is the current line so it wins the name.
  v2_bin="$(command -v opencode2 || true)"
  if [[ -n "$v2_bin" ]] && { [[ ! -e "$(dirname "$v2_bin")/opencode" ]] || [[ -L "$(dirname "$v2_bin")/opencode" ]]; }; then
    ln -sfn "$v2_bin" "$(dirname "$v2_bin")/opencode"
    echo "  aliased opencode -> opencode2"
  fi
  return 0
}

# Install oh-my-opencode-slim (agent orchestration plugin), tracking the
# latest published version (unpinned — v2 auto-refreshes unpinned plugins on
# startup, which is what we want here).
# Uses bunx when bun exists, else npx (the published CLI is a Node bundle).
install_omod_slim() {
  echo "Installing oh-my-opencode-slim@latest..."
  if command -v bun >/dev/null 2>&1; then
    bunx "oh-my-opencode-slim@latest" install --companion=no <<< "N" || \
      echo "WARNING: slim installer reported errors (continuing)." >&2
  else
    npx --yes "oh-my-opencode-slim@latest" install --companion=no <<< "N" || \
      echo "WARNING: slim installer reported errors (continuing)." >&2
  fi
  # Register the plugin unpinned in the opencode config (tracks latest).
  python3 - << 'PYEOF'
import json, os
path = os.path.expanduser("~/.config/opencode/opencode.json")
try:
    with open(path) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}
plugins = [p for p in cfg.get("plugin", []) if not str(p).startswith("oh-my-opencode-slim")]
plugins.append("oh-my-opencode-slim")
cfg["plugin"] = plugins
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
print("  slim registered (unpinned, tracks latest)")
PYEOF
  echo "  oh-my-opencode-slim installed."
}


# Overwrite the slim plugin's auto-generated preset (defaults to openai /
# gpt-5.6-* which don't apply here) with our Baseten chain.
configure_omod_slim_preset() {
  mkdir -p ~/.config/opencode
  python3 /dev/stdin << 'INNEREOF'
import json, os
path = os.path.expanduser("~/.config/opencode/oh-my-opencode-slim.json")
try:
    with open(path) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}
# Only set the preset if it's missing or still the default "openai" —
# don't clobber a user-chosen preset on re-runs.
# NOTE: the GLM-5.3 model chain here must mirror the models dict in
# configure_opencode_baseten_provider — update both together.
if cfg.get("preset") not in ("baseten", "baseten-fast"):
    cfg["preset"] = "baseten"
    cfg["presets"] = {
        "baseten": {
            "orchestrator": {"model": "baseten/zai-org/GLM-5.3"},
            "oracle": {"model": "baseten/zai-org/GLM-5.3"},
            "council": {"model": "baseten/zai-org/GLM-5.3"},
            "librarian": {"model": "baseten/zai-org/GLM-5.3-Flash"},
            "designer": {"model": "baseten/zai-org/GLM-5.3"},
            "fixer": {"model": "baseten/zai-org/GLM-5.3-Flash"},
            "explorer": {"model": "baseten/zai-org/GLM-5.3-Flash"},
        },
        "baseten-fast": {
            "orchestrator": {"model": "baseten/zai-org/GLM-5.3-Flash"},
            "oracle": {"model": "baseten/zai-org/GLM-5.3-Flash"},
            "council": {"model": "baseten/zai-org/GLM-5.3-Flash"},
            "librarian": {"model": "baseten/deepseek-ai/DeepSeek-V4-Flash-0731"},
            "designer": {"model": "baseten/zai-org/GLM-5.3-Flash"},
            "fixer": {"model": "baseten/zai-org/GLM-5.3-Flash"},
            "explorer": {"model": "baseten/deepseek-ai/DeepSeek-V4-Flash-0731"},
        },
    }
    with open(path, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    print("  slim preset set to baseten (GLM-5.3 chain)")
else:
    print(f"  slim preset already set to {cfg['preset']} — keeping it.")
INNEREOF
}

# Persist ~/.local/bin onto PATH in shell rc files (managed block).
persist_local_bin() {
  local rc_files=("$HOME/.bashrc")
  [[ -f "$HOME/.zshrc" ]] && rc_files+=("$HOME/.zshrc")
  local rc
  for rc in "${rc_files[@]}"; do
    touch "$rc"
    RC_FILE="$rc" python3 - "$rc" <<'PYEOF'
import os, re, sys
path = sys.argv[1]
line = 'export PATH="$HOME/.local/bin:$PATH"'
open_m = "# >>> ~/.local/bin on PATH (managed by dotfiles setup) >>>"
close_m = "# <<< ~/.local/bin >>>"
try:
    content = open(path).read()
except FileNotFoundError:
    content = ""
block = open_m + "\n" + line + "\n" + close_m
pat = re.compile(re.escape(open_m) + r".*?" + re.escape(close_m) + r"\n?", re.DOTALL)
if pat.search(content):
    content = pat.sub(lambda _m: block, content)
else:
    content = content.rstrip("\n")
    content = (content + "\n\n" + block + "\n") if content else (block + "\n")
with open(path, "w") as f:
    f.write(content)
PYEOF
  done
}


# Write oh-my-opencode-slim per-agent presets + model chains into the opencode
# config. Chains are intelligence-ordered: best Baseten model first, then
# progressively cheaper/flash variants, then free OpenCode/OpenRouter models.
# Each agent's primary model is its "best" (deep reasoning for orchestrator/
# oracle/council, fast for explorer/fixer/librarian).
configure_omod_slim_presets() {
  mkdir -p ~/.config/opencode
  python3 - "$HOME" << 'PYEOF'
import json, os

home = os.environ["HOME"]
path = os.path.join(home, ".config/opencode/opencode.json")
try:
    with open(path) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}

# Per-agent model presets. Format: presets.<name>.<agent> = {model, variant?}
cfg["presets"] = {
    "default": {
        "orchestrator": {"model": "baseten/zai-org/GLM-5.3"},
        "oracle":        {"model": "baseten/zai-org/GLM-5.3"},
        "council":       {"model": "baseten/zai-org/GLM-5.3"},
        "librarian":     {"model": "baseten/zai-org/GLM-5.3-Flash"},
        "designer":      {"model": "baseten/zai-org/GLM-5.3"},
        "fixer":         {"model": "baseten/zai-org/GLM-5.3-Flash"},
        "explorer":      {"model": "baseten/zai-org/GLM-5.3-Flash"},
    },
    "best": {
        "orchestrator": {"model": "baseten/zai-org/GLM-5.3"},
        "oracle":        {"model": "baseten/zai-org/GLM-5.3"},
        "council":       {"model": "baseten/zai-org/GLM-5.3"},
        "librarian":     {"model": "baseten/zai-org/GLM-5.3"},
        "designer":      {"model": "baseten/zai-org/GLM-5.3"},
        "fixer":         {"model": "baseten/zai-org/GLM-5.3"},
        "explorer":      {"model": "baseten/zai-org/GLM-5.3"},
    },
    "fast": {
        "orchestrator": {"model": "baseten/zai-org/GLM-5.3-Flash"},
        "oracle":        {"model": "baseten/zai-org/GLM-5.3-Flash"},
        "council":       {"model": "baseten/zai-org/GLM-5.3-Flash"},
        "librarian":     {"model": "baseten/deepseek-ai/DeepSeek-V4-Flash-0731"},
        "designer":      {"model": "baseten/zai-org/GLM-5.3-Flash"},
        "fixer":         {"model": "baseten/zai-org/GLM-5.3-Flash"},
        "explorer":      {"model": "baseten/deepseek-ai/DeepSeek-V4-Flash-0731"},
    },
    "free": {
        "orchestrator": {"model": "opencode/nvidia/nemotron-3-ultra-550b-a55b:free"},
        "oracle":        {"model": "opencode/nvidia/nemotron-3-ultra-550b-a55b:free"},
        "council":       {"model": "opencode/nvidia/nemotron-3-ultra-550b-a55b:free"},
        "librarian":     {"model": "opencode/nvidia/nemotron-3-ultra-550b-a55b:free"},
        "designer":      {"model": "opencode/nvidia/nemotron-3-ultra-550b-a55b:free"},
        "fixer":         {"model": "opencode/nvidia/nemotron-3-ultra-550b-a55b:free"},
        "explorer":      {"model": "opencode/nvidia/nemotron-3-ultra-550b-a55b:free"},
    },
}

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
print("  per-agent presets configured (default/best/fast/free)")
PYEOF
  echo "  oh-my-opencode-slim presets written."
}
