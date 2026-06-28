#!/usr/bin/env bash
set -euo pipefail

# This script is idempotent: it can be run both for initial installs and updates.

# Helper: append a line to a file only if it's not already present.
append_once() {
  local file="$1"
  local line="$2"
  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# Install/update system packages (btop).
# Use sudo only if available and we're not already root; otherwise call apt-get
# directly. All of this is best-effort (tolerate missing apt / non-root / non-Debian).
if command -v sudo >/dev/null 2>&1 && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  ADO="sudo apt-get"
else
  ADO="apt-get"
fi
$ADO update -y || true
$ADO install -y btop || true

# Download and install/update nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash

# Ensure nvm init lines are in .bashrc (the installer sometimes fails to add them)
append_once "$HOME/.bashrc" 'export NVM_DIR="$HOME/.nvm"'
append_once "$HOME/.bashrc" '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'

# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"

# Download and install/update Node.js:
nvm install 26
nvm use 26

# Verify the Node.js version:
node -v # Should print "v26.2.0".

# Verify npm version:
npm -v # Should print "11.13.0".

# Install/update opencode v2 (@next beta -> `opencode2` binary)
# v2 ships as @opencode-ai/cli@next and installs a SEPARATE `opencode2` binary so
# it coexists with any v1 `opencode` install. npm's global bin is already on PATH
# via nvm, so no extra PATH line is needed (v1 used ~/.opencode/bin from its curl
# installer; v2-via-npm does not use that directory).
echo "Installing opencode v2..."
npm i -g @opencode-ai/cli@next
opencode2 --version

# Install/update croc
echo "Installing croc..."
curl -fsSL https://getcroc.schollz.com | bash

# Install/update gh
echo "Installing gh..."
curl -sS https://webi.sh/gh | sh

# Add gh to PATH (idempotent)
append_once "$HOME/.bashrc" 'export PATH="$HOME/.local/bin:$PATH"'

# Install/update uv
echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install/update Factory CLI
echo "Installing Factory CLI..."
curl -fsSL https://app.factory.ai/cli | sh

# Install/update Cursor CLI
# echo "Installing Cursor CLI..."
# curl https://cursor.com/install -fsS | bash

# Install/update paseo
echo "Installing paseo..."
npm install -g @getpaseo/cli && paseo

# Configure git identity for remote dev pods (idempotent)
echo "Configuring git identity..."
git config --global user.name "Dhruv Singal"
git config --global user.email "dhruvsingalabc@gmail.com"

# Configure Factory custom models (Baseten BYOK)
echo "Configuring Factory Baseten custom models..."
# ---------------------------------------------------------------------------
# IMPORTANT: You must fill in your Baseten API key below before running this!
#
#   Get your API key from: https://app.baseten.co/settings
#
#   Replace the empty "" for BASETEN_API_KEY with your key, e.g.:
#       BASETEN_API_KEY="AB12CD34.yourKeyHere..."
#
#   This script writes the key into:  ~/.factory/settings.json
#   (under the "customModels" array's "apiKey" field for each Baseten model)
# ---------------------------------------------------------------------------
BASETEN_API_KEY=""  # <-- FILL ME IN: paste your Baseten API key between the quotes

if [[ -z "$BASETEN_API_KEY" ]]; then
  echo "WARNING: BASETEN_API_KEY is empty in $0. Skipping Baseten model config."
  echo "         Edit this script, fill in BASETEN_API_KEY, and re-run to enable Baseten models."
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

existing = {m.get("model") for m in settings["customModels"]}
for m in baseten_models:
    if m["model"] not in existing:
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

echo "Setup complete!"
