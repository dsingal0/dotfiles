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

# Source ~/.cursor/env (CURSOR_API_KEY for the Cursor CLI `agent`) into shell
# rc files via a managed block so new shells pick up the API key. The key file
# itself is NOT stored in this repo; it lives at ~/.cursor/env (mode 600) and
# is carried to dev pods by `devpod-bundle`. Idempotent.
configure_cursor() {
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
  if [[ -f "$HOME/.cursor/env" ]]; then
    echo "Cursor CLI: ~/.cursor/env present; new shells will export CURSOR_API_KEY."
  else
    echo "NOTE: ~/.cursor/env not found yet. Create it with:"
    echo "      printf 'export CURSOR_API_KEY=crsr_...\\n' > ~/.cursor/env && chmod 600 ~/.cursor/env"
    echo "      or restore it via: devpod-bundle --restore <bundle>.tar.gz"
  fi
}

# Symlink every skill under <repo>/skills/<name>/SKILL.md into each harness's
# global skills directory so droid, opencode, cursor-cli, and grok all see the
# same personal skill set. Idempotent: re-runs refresh the symlinks.
#
# Targets (primary path per harness; avoids multi-scan duplicates):
#   Factory / droid  -> ~/.factory/skills/
#   OpenCode         -> ~/.config/opencode/skills/
#   Cursor CLI       -> ~/.cursor/skills/
#   xAI / Grok Build -> ~/.grok/skills/
#
# Existing non-symlink directories are left alone (with a warning) so vendor
# or hand-installed skills are not clobbered.
# Pass the repo root as $1.
install_shared_skills() {
  local repo_dir="$1"
  local skills_src="$repo_dir/skills"

  if [[ ! -d "$skills_src" ]]; then
    echo "NOTE: no skills/ directory at $skills_src; skipping skill install."
    return 0
  fi

  local targets=(
    "$HOME/.factory/skills"
    "$HOME/.config/opencode/skills"
    "$HOME/.cursor/skills"
    "$HOME/.grok/skills"
  )

  local target skill_dir name dest count=0
  for target in "${targets[@]}"; do
    mkdir -p "$target"
  done

  echo "Installing shared skills from $skills_src ..."
  for skill_dir in "$skills_src"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_dir="${skill_dir%/}"
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    name="$(basename "$skill_dir")"

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

  echo "Shared skills installed: $count skill(s) -> factory, opencode, cursor, grok."
}

# Install third-party skill packs globally via the skills.sh CLI (npx skills).
# Idempotent: re-runs refresh to latest from each source.
#
# Packs:
#   https://github.com/mattpocock/skills
#   https://github.com/basetenlabs/baseten-skills
#   https://github.com/expo/skills
#
# Agents are listed explicitly rather than --agent '*': Eve and PromptScript
# do not support global skill installation and would otherwise emit failures.
# `universal` covers ~/.agents/skills (also picked up by Grok Build, etc.).
#
# Requires node/npx (installed earlier by both bootstrap scripts).
install_skill_packages() {
  if ! command -v npx >/dev/null 2>&1; then
    echo "WARNING: npx not found; skipping third-party skill packages."
    return 0
  fi

  local packs=(
    "mattpocock/skills"
    "basetenlabs/baseten-skills"
    "expo/skills"
  )
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

  # Resolve latest release tag via GitHub API; fall back to a known good version.
  local tag
  tag="$(curl -fsSL https://api.github.com/repos/basetenlabs/baseten-cli/releases/latest \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["tag_name"])' 2>/dev/null \
    || true)"
  tag="${tag:-v0.2.0}"
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
#   - truss    (Baseten model authoring / deploy-loop)
#   - magic-wormhole (file transfer, replaces croc)
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
