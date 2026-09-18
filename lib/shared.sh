#!/usr/bin/env bash
# shared.sh - common logic sourced by both setup.sh (Linux) and brew-setup.sh (macOS).
#
# This file is NOT executable on its own; it must be sourced after SCRIPT_DIR is
# set, e.g.:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$SCRIPT_DIR/lib/shared.sh"
#
# It exposes the per-harness configuration functions (omp and droid/Factory)
# shared by the bootstrap scripts.


# Ensure runlayer MCP (https://baseten.runlayer.com/mcp) is configured in
# the two harnesses: omp and droid/Factory. Idempotent.
configure_runlayer_mcp() {
  local url="https://baseten.runlayer.com/mcp"
  # omp -> ~/.omp/agent/mcp.json (mcpServers.<name> with type http)
  mkdir -p ~/.omp/agent
  python3 - << 'PYEOF'
import json, os
path = os.path.expanduser("~/.omp/agent/mcp.json")
try:
    with open(path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}
data.setdefault("mcpServers", {})
data["mcpServers"]["runlayer"] = {"type": "http", "url": "https://baseten.runlayer.com/mcp"}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
  echo "  omp runlayer MCP configured"
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

}

# Symlink the repo's global omp instructions into ~/.omp/agent/AGENTS.md so
# every project session picks up the same global rules (no /tmp, lowercase
# names, worktrees above the repo, Docker host networking). Idempotent:
# re-runs refresh the symlink.
# Pass the repo root as $1.
install_global_agents_md() {
  local repo_dir="$1"
  local src="$repo_dir/config/omp/AGENTS.md"
  local dest="$HOME/.omp/agent/AGENTS.md"

  if [[ ! -f "$src" ]]; then
    echo "NOTE: no global AGENTS.md at $src; skipping."
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    # Preserve any hand-edited copy before taking over with the managed symlink.
    mv -f "$dest" "$dest.bak"
    echo "  backed up existing ~/.omp/agent/AGENTS.md -> AGENTS.md.bak"
  fi
  ln -sfn "$src" "$dest"
  echo "Global omp AGENTS.md installed: $dest -> $src"
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
    "deepseek-ai/DeepSeek-V4-Pro-0813": {"none", "minimal", "low", "medium", "high", "xhigh", "max"},
    "zai-org/GLM-5.3": {"none", "high", "max"},
    "zai-org/GLM-5.3-Flash": {"none", "high", "max"},
    "zai-org/GLM-5.2": {"none", "high", "max"},
    "zai-org/GLM-5.2-Fast": {"none", "high", "max"},
}
REASONING_EFFORT_VALUE = {
    "deepseek-ai/DeepSeek-V4-Pro-0813": "high",
    "zai-org/GLM-5.3": "high",
    "zai-org/GLM-5.3-Flash": "high",
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
    baseten_model("zai-org/GLM-5.3", "GLM 5.3 [Baseten]", True, 262144),
    baseten_model("zai-org/GLM-5.3-Flash", "GLM 5.3 Flash [Baseten]", True, 262144),
    baseten_model("deepseek-ai/DeepSeek-V4-Pro-0813", "DeepSeek V4 Pro [Baseten]", True, 262144),
    baseten_model("deepseek-ai/DeepSeek-V4-Flash-0731", "DeepSeek V4 Flash [Baseten]", True, 1048576),
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

# Truly YOLO: default every new droid session to full autonomy (the
# interactive --auto high equivalent — no permission prompts), and trust
# everything under $HOME so droid never asks to trust a home-dir folder.
from datetime import datetime, timezone
settings.setdefault("sessionDefaultSettings", {})
settings["sessionDefaultSettings"].update({
    "autonomyMode": "auto-high",
    "interactionMode": "auto",
    "autonomyLevel": "high",
})
settings.setdefault("trustedFolders", {})
settings["trustedFolders"].setdefault(os.path.expanduser("~"), {
    "trustedAt": datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z"),
})

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

# Generic managed-block writer shared by persist_export_to_rc. For each rc file
# (~/.bashrc always; ~/.zshrc if it exists), remove any previous block between
# the two markers, then append the fresh block at the end of the file.
# Usage: write_managed_rc_block <open_marker> <close_marker> <body>
write_managed_rc_block() {
  local open_m="$1" close_m="$2" body="$3"
  local rc rc_files=( "$HOME/.bashrc" )
  [[ -f "$HOME/.zshrc" ]] && rc_files+=( "$HOME/.zshrc" )
  for rc in "${rc_files[@]}"; do
    touch "$rc"
    OPEN_M="$open_m" CLOSE_M="$close_m" BODY="$body" python3 - "$rc" << 'PYEOF'
import os, re, sys

path = sys.argv[1]
open_m = os.environ["OPEN_M"]
close_m = os.environ["CLOSE_M"]
body = os.environ["BODY"]
block = "%s\n%s\n%s" % (open_m, body, close_m)

try:
    with open(path) as f:
        content = f.read()
except FileNotFoundError:
    content = ""

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

# Persist `export <VAR>=<value>` into shell rc files (~/.bashrc always;
# ~/.zshrc if it exists) inside a managed block so re-runs update the value
# instead of duplicating lines. New shells pick it up automatically; existing
# shells need `source ~/.bashrc` (or a new terminal) to see it. The value is
# single-quoted and embedded single quotes are escaped.
persist_export_to_rc() {
  local var="$1" value="$2"
  [[ -z "$value" ]] && return 0
  local qesc="'\''"
  local escaped="${value//\'/${qesc}}"
  write_managed_rc_block \
    "# >>> ${var} (managed by dotfiles setup) >>>" \
    "# <<< ${var} <<<" \
    "export ${var}='${escaped}'"
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
# Configure the RTK integration used by OMP.
# OMP needs the native extension (`--agent omp`); Pi is a different harness and
# must not be used as an OMP substitute. Idempotent.
configure_rtk() {
  if ! command -v rtk >/dev/null 2>&1; then
    echo "WARNING: rtk not found; skipping RTK integration."
    return 0
  fi

  echo "Configuring RTK integration for OMP..."
  RTK_TELEMETRY_DISABLED=1 rtk init -g --agent omp --hook-only --no-patch
  RTK_TELEMETRY_DISABLED=1 rtk init --show
}

# Symlink every skill under <repo>/skills/<name>/SKILL.md into the configured
# harnesses' global skills directories. OMP and Factory droid are the supported
# harnesses in this setup.
# Idempotent: re-runs refresh to the latest local skill contents.
#
# Targets (primary path per harness; avoids multi-scan duplicates):
#   Factory / droid -> ~/.factory/skills/
#   omp             -> ~/.omp/agent/skills/
#
# Existing non-symlink directories are left alone (with a warning) so vendor
# or hand-installed skills are not clobbered.
# Pass the repo root as $1. Pass a space-separated list of skill names as $2
# to skip them (e.g. design skills that only brew-setup.sh installs).
install_shared_skills() {
  local repo_dir="$1"
  local exclude_names="${2:-}"
  local skills_src="$repo_dir/skills"

  if [[ ! -d "$skills_src" ]]; then
    echo "NOTE: no skills/ directory at $skills_src; skipping skill install."
    return 0
  fi

  local targets=(
    "$HOME/.factory/skills"
    "$HOME/.omp/agent/skills"
  )

  local target skill_dir name dest count=0
  for target in "${targets[@]}"; do
    mkdir -p "$target"
  done

  local harness_names="factory, omp"

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
      -a universal -a droid \
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
# `universal` covers ~/.agents/skills, which omp reads natively.
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
  # omp is covered by `universal` (~/.agents/skills), which it reads natively.
  local agents=(
    universal
    droid
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
# (.cursor, .grok, .factory, .omp) have config files and are
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
    "$HOME/.omp/agent/skills/baseten"
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



# Persist ~/.local/bin onto PATH in shell rc files (managed block), using
# the same marker scheme as persist_export_to_rc so the block stays unique.
persist_local_bin() {
  write_managed_rc_block \
    "# >>> ~/.local/bin on PATH (managed by dotfiles setup) >>>" \
    "# <<< ~/.local/bin >>>" \
    'export PATH="$HOME/.local/bin:$PATH"'
}

# Login shells (tmux panes run `-bash`) read ~/.profile, not ~/.bashrc, where
# installers (bun.sh, nvm) and the persist_*_to_rc helpers append PATH/env
# setup. Bridge the two so new shells pick up tool PATHs without restarting
# the tmux server (a running tmux server freezes PATH at server start).
link_profile_to_bashrc() {
  if [[ -f "$HOME/.profile" ]] && ! grep -qxF '. "$HOME/.bashrc"' "$HOME/.profile"; then
    echo '. "$HOME/.bashrc"' >> "$HOME/.profile"
  fi
}


# Vanilla omp setup: built-in agents/roles, no plugins.
install_omp() {
  echo "Installing oh-my-pi (omp)..."
  # The omp package ships a bun-compiled binary (#!/usr/bin/env bun), so bun
  # is required even when the npm fallback install path below is used. The
  # bun.sh installer needs unzip (setup.sh/setup-arch.sh apt/pacman-install
  # it; macOS ships /usr/bin/unzip; brew-setup.sh installs the bun formula).
  if ! command -v bun >/dev/null 2>&1; then
    echo "  bun not found (required by the omp binary); installing via bun.sh..."
    curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1 \
      || echo "WARNING: bun install failed; will try the npm fallback for omp." >&2
    export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
    export PATH="$BUN_INSTALL/bin:$PATH"
  fi
  if command -v bun >/dev/null 2>&1; then
    bun install -g @oh-my-pi/pi-coding-agent \
      || echo "WARNING: omp install failed (continuing)." >&2
  else
    npm install -g @oh-my-pi/pi-coding-agent \
      || echo "WARNING: omp install failed (continuing)." >&2
  fi
}

# Configure omp (vanilla — no custom agents; omp's built-in task tool and the
# model roles are the whole setup):
#   ~/.omp/agent/models.yml    Baseten fallback models + optional OpenRouter latest
#   ~/.omp/agent/config.yml    one ordered ladder shared by all model roles
# Idempotent: every file is regenerated on each run. Keys are embedded at
# setup time (repo is private) and models.yml is chmod 600. The global
# AGENTS.md symlink is owned by install_global_agents_md, not this function.
configure_omp() {
  if [[ -z "${BASETEN_API_KEY:-}" ]]; then
    echo "WARNING: BASETEN_API_KEY is not set. Skipping omp config."
    echo "         To enable: cp .env.example .env and fill in your key."
    return 0
  fi
  mkdir -p ~/.omp/agent

  # --- models.yml: Baseten fallback models + latest OpenRouter DeepSeek -------
  # Keep every requested Baseten fallback explicit. compat blocks replace rather
  # than merge in omp, so each model spells out its complete wire contract.
  cat > ~/.omp/agent/models.yml <<EOF
# Managed by dotfiles setup (configure_omp in lib/shared.sh) — hand edits are
# overwritten on the next setup run.
providers:
  baseten:
    baseUrl: https://inference.baseten.co/v1
    api: openai-completions
    apiKey: "${BASETEN_API_KEY}"
    authHeader: true
    models:
      - id: deepseek-ai/DeepSeek-V4.1-Flash
        name: DeepSeek V4.1 Flash
        reasoning: false
        input: [text]
        contextWindow: 1048576
        maxTokens: 32768
        compat:
          supportsDeveloperRole: false
          supportsReasoningEffort: false
          maxTokensField: max_tokens
      - id: zai-org/GLM-5.3-Flash
        name: GLM 5.3 Flash
        reasoning: true
        input: [text]
        contextWindow: 200000
        maxTokens: 262144
        thinking: { mode: effort, minLevel: high, maxLevel: max }
        compat:
          supportsDeveloperRole: false
          supportsReasoningEffort: true
          maxTokensField: max_tokens
      - id: zai-org/GLM-5.3
        name: GLM 5.3
        reasoning: true
        input: [text]
        contextWindow: 200000
        maxTokens: 262144
        thinking: { mode: effort, minLevel: high, maxLevel: max }
        compat:
          supportsDeveloperRole: false
          supportsReasoningEffort: true
          maxTokensField: max_tokens
      - id: deepseek-ai/DeepSeek-V4-Flash-0731
        name: DeepSeek V4 Flash 0731
        reasoning: false
        input: [text]
        contextWindow: 200000
        maxTokens: 1048576
        compat:
          supportsDeveloperRole: false
          supportsReasoningEffort: false
          maxTokensField: max_tokens
      - id: deepseek-ai/DeepSeek-V4-Pro-0813
        name: DeepSeek V4 Pro 0813
        reasoning: true
        input: [text]
        contextWindow: 200000
        maxTokens: 262144
        thinking: { mode: effort, minLevel: high, maxLevel: max }
        compat:
          supportsDeveloperRole: false
          supportsReasoningEffort: true
          maxTokensField: max_tokens
  # Local SWE-2 slice on rack 17 (kimi-k3-swe-2-omp, 1xTP8 DSpark batch-4).
  # Served via a persistent port-forward on 127.0.0.1:18090; auth none.
  # Unreachable entries are skipped by the fallback ladder, so this is safe
  # to keep even when the slice is down.
  swe2:
    baseUrl: http://127.0.0.1:18090/v1
    api: openai-completions
    auth: none
    models:
      - id: moonshotai/Kimi-K3
        name: SWE-2 (rack17 omp slice)
        reasoning: true
        input: [text]
        contextWindow: 1048576
        maxTokens: 49152
        thinking: { mode: effort, minLevel: low, maxLevel: max }
        compat:
          supportsDeveloperRole: false
          supportsReasoningEffort: true
          maxTokensField: max_tokens
EOF

  # OpenRouter fallback: use only the rolling latest DeepSeek Flash alias.
  # No OpenRouter free-tier models are configured. The alias is quoted because
  # its model id intentionally begins with "~".
  if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    cat >> ~/.omp/agent/models.yml <<EOF
  openrouter:
    baseUrl: https://openrouter.ai/api/v1
    api: openai-completions
    apiKey: "${OPENROUTER_API_KEY}"
    authHeader: true
    models:
      - id: "~deepseek/deepseek-flash-latest"
        name: DeepSeek Flash Latest (OpenRouter)
        reasoning: true
        input: [text]
        contextWindow: 1048576
        maxTokens: 384000
        thinking: { mode: effort, minLevel: low, maxLevel: max }
        compat:
          maxTokensField: max_tokens
EOF
  else
    echo "NOTE: OPENROUTER_API_KEY is not set. Latest DeepSeek Flash fallback skipped."
  fi
  chmod 600 ~/.omp/agent/models.yml

  # --- config.yml: one ordered ladder for every model role ---------------------
  # The primary route is the local SWE-2 rack-17 slice for workhorse roles
  # (default/task/slow/plan); smol/tiny/commit/advisor stay on Copilot Gemini
  # to keep the batch-4 slice free for real work. Native fallback entries are resolved
  # only when their provider is authenticated; unavailable entries are skipped.
  # Grok Build/SuperGrok is intentionally tried before Cursor Grok 4.6.
  # Cursor is restricted to its exact Grok 4.6 route; no other Cursor model can
  # enter this ladder. Baseten entries follow both subscription routes.
  # OpenAI Codex Luna and the latest OpenRouter DeepSeek Flash are the final
  # safety net. All configured models are text-only; no vision role is set.

  cat > ~/.omp/agent/config.yml <<EOF
# Managed by dotfiles setup (configure_omp in lib/shared.sh) — hand edits are
# overwritten on the next setup run.
modelRoles:
  default: swe2/moonshotai/Kimi-K3
  smol: github-copilot/gemini-3.8-flash
  slow: swe2/moonshotai/Kimi-K3:high
  task: swe2/moonshotai/Kimi-K3
  tiny: github-copilot/gemini-3.8-flash
  commit: github-copilot/gemini-3.8-flash
  plan: swe2/moonshotai/Kimi-K3:high
  advisor: github-copilot/gemini-3.8-flash

retry:
  enabled: true
  modelFallback: true
  fallbackRevertPolicy: cooldown-expiry
  maxRetries: 10
  # Preflight supported provider usage before each request. At the 1% remaining
  # reserve, switch before included subscription usage is exhausted, avoiding
  # intentional on-demand spill. Unknown usage still fails open per omp policy.
  usageAwareFallback: true
  usageReservePct: 1
  usageReservePolicy: auto
  fallbackChains:
    # Ordered fallback ladder:
    # Grok Build/SuperGrok Grok 4.6 -> Cursor Grok 4.6 -> Baseten DeepSeek
    # V4.1 Flash -> Baseten GLM-5.3 Flash -> Baseten GLM-5.3 -> Baseten
    # DeepSeek V4 Flash 0731 -> Baseten DeepSeek V4 Pro -> OpenAI Codex Luna
    # -> the rolling latest DeepSeek Flash alias on OpenRouter.
    default:
      - xai-oauth/grok-4.6
      - cursor/grok-4.6
      - baseten/deepseek-ai/DeepSeek-V4.1-Flash
      - baseten/zai-org/GLM-5.3-Flash
      - baseten/zai-org/GLM-5.3
      - baseten/deepseek-ai/DeepSeek-V4-Flash-0731
      - baseten/deepseek-ai/DeepSeek-V4-Pro-0813
      - openai-codex/gpt-5.6-luna
      - openrouter/~deepseek/deepseek-flash-latest
EOF

  # Vanilla: no custom agents under ~/.omp/agent/agents — omp's built-in
  # task tool spawns subagents on the "task" role, which inherits the
  # default chain above. Remove specialist agents from earlier setup
  # runs so the config stays clean.
  rm -f ~/.omp/agent/agents/{explorer,librarian,fixer,designer,oracle}.md
  rmdir ~/.omp/agent/agents 2>/dev/null || true

  echo "  omp configured (models.yml, config.yml — vanilla, no custom agents)."
  echo "  Global AGENTS.md symlink + skills + runlayer MCP are owned by other functions."
}
