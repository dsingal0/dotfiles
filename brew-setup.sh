#!/bin/bash
set -euo pipefail

# Install Homebrew if not present
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Fetch latest formulae and casks
brew update

# Taps
brew tap manaflow-ai/cmux

# Packages to install and keep up to date
# `node` provides npm, used below to install opencode v2 (@next beta has no brew formula).
FORMULAS=(gh node rtk)
CASKS=(cmux cursor-cli droid)

# Install (no-op if already installed) then upgrade to latest
for pkg in "${FORMULAS[@]}"; do
  brew install "$pkg"
  brew upgrade "$pkg"
done

for pkg in "${CASKS[@]}"; do
  brew install --cask "$pkg"
  brew upgrade --cask "$pkg"
done

# Install/update opencode v2 (@next beta -> `opencode2` binary)
# There is no brew formula for opencode v2; it ships as @opencode-ai/cli@next via npm.
# npm comes from the `node` formula above and installs globally into the brew
# prefix bin (on PATH), so no PATH append is needed. The `opencode2` binary is
# separate from any v1 `opencode` install and coexists with it.
echo "Installing opencode v2..."
npm i -g @opencode-ai/cli@next
opencode2 --version

# Configure Factory custom models (Baseten BYOK)
# API key is read from .env in the repo root (kept local, never committed).
# Copy .env.example to .env and fill in your key:
#   cp .env.example .env
# Key can also be exported directly: BASETEN_API_KEY=your_key ./brew-setup.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a; source "$SCRIPT_DIR/.env"; set +a
fi

if [[ -z "${BASETEN_API_KEY:-}" ]]; then
  echo "WARNING: BASETEN_API_KEY is not set. Skipping Baseten model config."
  echo "         To enable: cp .env.example .env and fill in your key, or export BASETEN_API_KEY."
else
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
    {
        "model": "zai-org/GLM-5.2-1M",
        "displayName": "GLM 5.2 1M [Baseten]",
        "baseUrl": "https://inference.baseten.co/v1",
        "apiKey": api_key,
        "provider": "generic-chat-completion-api",
        "maxOutputTokens": 8192,
        "noImageSupport": True
    }
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
fi

# Configure opencode v2 custom model + permissions (Baseten BYOK - GLM 5.2 1M)
# Adds the GLM-5.2-1M model under the "baseten" provider with max reasoning,
# thinking preservation (interleaved reasoning_content), and tool calling.
# NOTE: The Baseten API key for opencode is stored separately via `/connect`
#       (run `opencode2` and issue /connect) in ~/.local/share/opencode/auth.json.
#       This config only defines the model.
#
# NOTE on schema: opencode2's CLI loads custom models from the V1 `provider`
#       (singular) config via its legacy Config.Service
#       (src/provider/provider.ts reads cfg.provider, NOT cfg.providers). The v2
#       `providers` (plural) schema is consumed only by the desktop/web catalog.
#       So the model below is intentionally kept in v1 schema (reasoning /
#       interleaved / tool_call / options) -- that is what `opencode2 models`
#       and session model resolution actually read. Forward-porting it to the
#       v2 `providers` plural shape would make the model invisible to opencode2.
#
# Permissions: opencode2's CLI reads cfg.permission (v1) via Permission.fromConfig
#       (src/permission/index.ts). A bare "allow" string is mishandled there, so
#       the working global allow-all is {"*":"allow"}.
echo "Configuring opencode v2 (Baseten model + permissions)..."
mkdir -p ~/.config/opencode
python3 - << 'PYEOF'
import json, os

config_path = os.path.expanduser("~/.config/opencode/opencode.jsonc")

# Read existing config (strip JSONC comments for parsing, preserve as JSONC on write)
try:
    with open(config_path, "r") as f:
        raw = f.read()
    # Naive string-aware comment stripper for parsing
    stripped = []
    in_string = False
    esc = False
    i = 0
    while i < len(raw):
        c = raw[i]
        if in_string:
            stripped.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_string = False
            i += 1
            continue
        if c == '"':
            in_string = True
            stripped.append(c)
            i += 1
            continue
        if c == "/" and i + 1 < len(raw) and raw[i+1] == "/":
            while i < len(raw) and raw[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < len(raw) and raw[i+1] == "*":
            i += 2
            while i + 1 < len(raw) and not (raw[i] == "*" and raw[i+1] == "/"):
                i += 1
            i += 2
            continue
        stripped.append(c)
        i += 1
    config = json.loads("".join(stripped))
except (FileNotFoundError, json.JSONDecodeError):
    config = {}

config.setdefault("$schema", "https://opencode.ai/config.json")

# Global allow-all permissions (v1 schema, read by opencode2 CLI). Idempotent.
config["permission"] = {"*": "allow"}

config.setdefault("provider", {})
config["provider"].setdefault("baseten", {})
config["provider"]["baseten"].setdefault("models", {})

# Only add the model if not already present (idempotent)
if "zai-org/GLM-5.2-1M" not in config["provider"]["baseten"]["models"]:
    config["provider"]["baseten"]["models"]["zai-org/GLM-5.2-1M"] = {
        "name": "GLM 5.2 1M [Baseten]",
        "reasoning": True,
        "tool_call": True,
        "interleaved": {
            "field": "reasoning_content"
        },
        "limit": {
            "context": 1048576,
            "input": 920000,
            "output": 65536
        },
        "options": {
            "reasoningEffort": "max"
        }
    }

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PYEOF

# Install paseo CLI via npm (latest npm from brew's node formula)
npm install -g @getpaseo/cli

# Remove stale downloads and old versions
brew cleanup --prune=all

echo "Done!"
