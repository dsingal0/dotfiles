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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared config helpers (opencode permission + Baseten BYOK models),
# deduplicated with brew-setup.sh so both bootstrap scripts stay in sync.
. "$SCRIPT_DIR/lib/shared.sh"

$ADO install -y btop libclang-dev tree libevent-dev libncurses-dev build-essential bison || true

# Install/update tmux from apt.
# Previously this built tmux from source with --prefix=/usr/local, which
# shadowed the distro binary in /usr/bin. We now use the distro package so the
# system tmux is what you get; see tmux.conf for a tmux 3.3+ version guard
# around the (3.2a-unavailable) extended-keys-format option.
echo "Installing tmux..."
$ADO install -y tmux
tmux -V

# Symlink tmux config (enables mouse scroll passthrough for Droid in tmux)
ln -sf "$SCRIPT_DIR/tmux.conf" "$HOME/.tmux.conf"
# Reload config into running tmux server, if any
tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true

# Link custom user scripts into ~/.local/bin (on PATH via the gh step below)
mkdir -p "$HOME/.local/bin"
ln -sf "$SCRIPT_DIR/bin/droid-export" "$HOME/.local/bin/droid-export"
ln -sf "$SCRIPT_DIR/bin/devpod-bundle" "$HOME/.local/bin/devpod-bundle"

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

# Install/update opencode (stable) - official curl installer preferred over
# package managers; npm is the fallback.
echo "Installing opencode..."
curl -fsSL https://opencode.ai/install | bash || npm i -g opencode-ai
# The opencode installer puts the binary in ~/.opencode/bin and only adds it to
# PATH via .bashrc (not sourced in this running shell), so export it here.
export PATH="$HOME/.opencode/bin:$PATH"
opencode --version

configure_opencode_permission

# Install droid (Factory CLI) via the official curl installer (preferred over
# package managers); npm is the fallback. allow-scripts covers the npm
# fallback paths for droid and opencode-ai.
npm config set allow-scripts="droid,opencode-ai" --location=user
echo "Installing droid..."
curl -fsSL https://app.factory.ai/cli | sh || npm install -g droid

# Install/update gh
echo "Installing gh..."
curl -sS https://webi.sh/gh | sh

# Add gh to PATH (idempotent)
append_once "$HOME/.bashrc" 'export PATH="$HOME/.local/bin:$PATH"'

# Install/update uv
echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh
# Ensure uv is on PATH for the rest of this script (installer targets ~/.local/bin)
export PATH="$HOME/.local/bin:$PATH"
# shellcheck disable=SC1091
\. "$HOME/.local/bin/env" 2>/dev/null || true

# Install/update Rust and Cargo
echo "Installing Rust..."
if command -v rustup >/dev/null 2>&1; then
  rustup update stable
else
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
# Ensure cargo/rustc are on PATH for the rest of this script
\. "$HOME/.cargo/env" 2>/dev/null || true
rustc --version
cargo --version

# Set LIBCLANG_PATH for bindgen (needed by Rust crates that wrap C/C++ libs)
for d in /usr/lib/llvm-*/lib; do
  if [[ -f "$d/libclang.so" ]]; then
    append_once "$HOME/.bashrc" "export LIBCLANG_PATH=\"$d\""
    break
  fi
done

# Install/update Cursor CLI
echo "Installing Cursor CLI..."
curl https://cursor.com/install -fsS | bash

# Install/update paseo (pre-release track via the `beta` dist-tag)
echo "Installing paseo..."
npm install -g @getpaseo/cli@beta && paseo

# Install/update rtk (Rust Token Killer) - CLI proxy that cuts LLM token usage.
# Single Rust binary in ~/.local/bin; ensure that dir is on PATH for this script
# (the .bashrc append below only applies to future shells).
export PATH="$HOME/.local/bin:$PATH"
echo "Installing rtk..."
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
rtk --version

# Initialize rtk hooks for the agents I use that rtk supports natively.
# OpenCode (plugin) and Cursor (preToolUse hook in ~/.cursor/hooks.json).
# Cursor uses --hook-only --no-patch so it skips the Claude Code RTK.md /
# CLAUDE.md / settings.json artifacts (I don't use Claude Code).
# Note: rtk has no native Droid/Factory integration; Droid is not wired here.
RTK_TELEMETRY_DISABLED=1 rtk init -g --opencode
# Cursor desktop isn't installed on Linux dev pods, so ~/.cursor may not exist;
# rtk writes a temp file there during init and errors out without the dir.
mkdir -p "$HOME/.cursor"
RTK_TELEMETRY_DISABLED=1 rtk init -g --agent cursor --hook-only --no-patch
rtk init --show

# Configure git identity for remote dev pods (idempotent)
echo "Configuring git identity..."
git config --global user.name "Dhruv Singal"
git config --global user.email "dhruvsingalabc@gmail.com"

# Configure Factory: Baseten BYOK custom models (~/.factory/settings.json) and
# FACTORY_API_KEY exported to shell rc files for the droid CLI.
# Keys are read from .env in the repo root (kept local, never committed).
# Copy .env.example to .env and fill in your keys:
#   cp .env.example .env
# Keys can also be exported directly: BASETEN_API_KEY=... FACTORY_API_KEY=... ./setup.sh
configure_factory "$SCRIPT_DIR"
configure_cursor

# Install personal skills into every harness (droid / opencode / cursor)
install_shared_skills "$SCRIPT_DIR" false

# Third-party skill packs (mattpocock + basetenlabs) for all agents
install_skill_packages

# Baseten CLI (https://github.com/basetenlabs/baseten-cli)
# Homebrew if available, else GitHub release -> ~/.local/bin
install_baseten_cli

# Install/update Herdr bash completions (herdr is installed out-of-band; this
# regenerates the script so it stays in sync with the installed binary).
if command -v herdr >/dev/null 2>&1; then
  echo "Installing Herdr bash completions..."
  mkdir -p "$HOME/.local/share/bash-completion/completions"
  herdr completion bash > "$HOME/.local/share/bash-completion/completions/herdr"
  append_once "$HOME/.bashrc" '# Herdr bash completions (managed by dotfiles setup)'
  append_once "$HOME/.bashrc" '[[ -r "$HOME/.local/share/bash-completion/completions/herdr" ]] && source "$HOME/.local/share/bash-completion/completions/herdr"'
fi

# ~/venv with truss (Baseten model authoring / deploy-loop) and magic-wormhole
ensure_venv

# Install/update iTerm2 shell integration + utilities (works over SSH too, so
# dev pods get marks/badges in local iTerm2 sessions). Best-effort.
echo "Installing iTerm2 shell integration..."
curl -L https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh | bash || true

echo "Setup complete!"
