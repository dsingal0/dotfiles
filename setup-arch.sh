#!/usr/bin/env bash
set -euo pipefail

# Arch Linux port of setup.sh: same toolchain, but system packages come from
# pacman (official repos) and paru (AUR) instead of apt.
# This script is idempotent: it can be run both for initial installs and updates.

# Helper: append a line to a file only if it's not already present.
append_once() {
  local file="$1"
  local line="$2"
  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared config helpers (opencode permission + Baseten BYOK models),
# deduplicated with setup.sh / brew-setup.sh so all bootstrap scripts stay in sync.
. "$SCRIPT_DIR/lib/shared.sh"

# Use sudo only if available and we're not already root; otherwise call pacman
# directly. All of this is best-effort (tolerate non-root / non-Arch).
if command -v sudo >/dev/null 2>&1 && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi

# Refresh the package DB and upgrade the system (idempotent; best-effort).
$SUDO pacman -Syu --noconfirm || true

# Install/update system packages from the official repos.
# Debian -> Arch package mapping:
#   build-essential -> base-devel (group)
#   libclang-dev    -> clang
#   libevent-dev    -> libevent
#   libncurses-dev  -> ncurses
#   gh              -> github-cli
# btop, tree, bison, tmux keep their names. git is added (required to clone AUR
# packages below); croc and uv are official-repo packages here, so they replace
# the GitHub-release / curl installers used by setup.sh.
$SUDO pacman -S --needed --noconfirm \
  base-devel git btop clang tree libevent ncurses bison tmux github-cli croc uv || true

# Install paru (AUR helper) from the AUR if not already present. paru is used
# for AUR-only packages below (rtk-bin). Building requires base-devel + git
# (installed above) and must run as a non-root user (makepkg refuses root).
# The build tree lives under ~/.cache, not /tmp (per the global AGENTS.md rule).
if ! command -v paru >/dev/null 2>&1 && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Installing paru (AUR helper)..."
  build_dir="$HOME/.cache/dotfiles/paru"
  rm -rf "$build_dir"
  mkdir -p "$(dirname "$build_dir")"
  git clone https://aur.archlinux.org/paru.git "$build_dir"
  ( cd "$build_dir" && makepkg -si --noconfirm )
  rm -rf "$build_dir"
  hash -r
fi

# tmux was installed via pacman above (distro package, not a source build).
# See tmux.conf for a tmux 3.3+ version guard around the (3.2a-unavailable)
# extended-keys-format option.
tmux -V

# Symlink tmux config (enables mouse scroll passthrough for Droid in tmux)
ln -sf "$SCRIPT_DIR/tmux.conf" "$HOME/.tmux.conf"
# Reload config into running tmux server, if any
tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true

# Link custom user scripts into ~/.local/bin (on PATH via the PATH export below)
mkdir -p "$HOME/.local/bin"
rm -f "$HOME/.local/bin/droid-export"
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

# Install/update pnpm (npm's faster replacement; corepack is no longer bundled
# with Node 25+, so bootstrap pnpm itself via npm).
npm install -g pnpm
# Ensure pnpm global binaries are on PATH for the rest of this script.
# (`pnpm bin -g` errors out when the dir isn't already on PATH, so derive it
# from the platform default instead.)
case "$(uname -s)" in
  Darwin) PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}" ;;
  *)      PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}" ;;
esac
export PNPM_HOME
export PATH="$PNPM_HOME/bin:$PATH"
ensure_pnpm_shell_path

# Uninstall the npm-managed copies of packages now handled by pnpm, so no
# stale npm binaries linger on PATH. opencode is still npm-managed (postinstall
# must run); drop droid/paseo here so they don't shadow the npm reinstall below.
npm uninstall -g droid @getpaseo/cli 2>/dev/null || true

# 2026-09 pivot: opencode (v1+v2) and OmO fully removed. jcode (our fork,
# built from source via cargo) is the primary coding agent; carry (PTY daemon
# with built-in iroh P2P) exposes jcode sessions to the phone app.
load_env_file "$SCRIPT_DIR"

uninstall_opencode_all_node_versions
uninstall_opencode_and_omo
ensure_jcode
configure_jcode_providers

# Install/update Meta CLI.
curl -fsSL https://dev.meta.ai/install.sh | bash

configure_runlayer_mcp

# Install droid (Factory CLI) via pnpm - the official curl installer lags the
# npm release (it's pinned to an older version), so pnpm gets the latest.
# Drop the droid binary left by the old curl installer (~/.local/bin/droid) so
# the npm-managed binary is the one on PATH. Also remove any stale pnpm-managed
# copy (npm always runs postinstall scripts, avoiding pnpm store-cache issues).
rm -f "$HOME/.local/bin/droid" 2>/dev/null || true
pnpm_remove_global droid
echo "Installing droid..."
npm install -g droid

# gh (GitHub CLI) is installed via pacman above (official `github-cli` package,
# which provides the `gh` binary) - no apt repo / keyring setup needed on Arch.

# Ensure ~/.local/bin is on PATH for future shells (custom scripts + baseten fallback)
append_once "$HOME/.bashrc" 'export PATH="$HOME/.local/bin:$PATH"'

# uv is installed via pacman above (official `uv` package); ensure ~/.local/bin
# is on PATH for the rest of this script (devpod-bundle, baseten fallback, etc.).
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

# Set LIBCLANG_PATH for bindgen (needed by Rust crates that wrap C/C++ libs).
# Arch's clang package installs libclang.so directly into /usr/lib, unlike
# Debian's /usr/lib/llvm-*/lib layout.
if [[ -f /usr/lib/libclang.so ]]; then
  append_once "$HOME/.bashrc" 'export LIBCLANG_PATH="/usr/lib"'
fi

# Install/update Cursor CLI
echo "Installing Cursor CLI..."
curl https://cursor.com/install -fsS | bash

# Install/update paseo (pre-release track via the `beta` dist-tag)
echo "Installing paseo..."
pnpm_remove_global @getpaseo/cli
npm install -g @getpaseo/cli@beta
# Bare `paseo` runs onboard and prompts for relay pairing + voice on a TTY.
# --no-relay skips device pairing; --voice disable skips voice model downloads.
paseo onboard --no-relay --voice disable

# Install/update rtk (Rust Token Killer) - CLI proxy that cuts LLM token usage.
# Installed from the AUR (rtk-bin = prebuilt binary) via paru; falls back to the
# official curl installer if paru is unavailable or the AUR build fails.
# Single Rust binary in ~/.local/bin; ensure that dir is on PATH for this script
# (the .bashrc append above only applies to future shells).
export PATH="$HOME/.local/bin:$PATH"
echo "Installing rtk..."
if command -v paru >/dev/null 2>&1; then
  paru -S --needed --noconfirm rtk-bin \
    || curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
else
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
fi
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
# Keys can also be exported directly: BASETEN_API_KEY=... FACTORY_API_KEY=... ./setup-arch.sh
configure_factory "$SCRIPT_DIR"
configure_cursor

# Remove the stale third-party baseten skill (basetenlabs/baseten-skills) so the
# repo's static, pruned, BIS-focused copy (skills/baseten/) gets symlinked in
# its place by install_shared_skills below.
cleanup_stale_baseten_skill

# Install personal skills into every harness (droid / opencode / cursor).
# Design skills (frontend-design) are skipped here and installed only by
# brew-setup.sh (macOS).
install_shared_skills "$SCRIPT_DIR" false "frontend-design"

# Third-party skill packs for all agents. Expo/EAS and design packs are skipped
# here (Linux dev pods) and installed only by brew-setup.sh (macOS). The baseten
# skill is no longer pulled from basetenlabs/baseten-skills (out of date); it
# lives as a static copy in this repo under skills/baseten/ (installed above).
install_skill_packages false false

# Baseten CLI (https://github.com/basetenlabs/baseten-cli)
# Homebrew if available, else GitHub release -> ~/.local/bin
install_baseten_cli

# croc file transfer (https://github.com/schollz/croc).
# Installed via pacman above (official `croc` package); fall back to the GitHub
# release binary if pacman didn't provide it.
if ! command -v croc >/dev/null 2>&1; then
  ensure_croc
fi

# Install/update Herdr bash completions (herdr is installed out-of-band; this
# regenerates the script so it stays in sync with the installed binary).
if command -v herdr >/dev/null 2>&1; then
  echo "Installing Herdr bash completions..."
  mkdir -p "$HOME/.local/share/bash-completion/completions"
  herdr completion bash > "$HOME/.local/share/bash-completion/completions/herdr"
  append_once "$HOME/.bashrc" '# Herdr bash completions (managed by dotfiles setup)'
  append_once "$HOME/.bashrc" '[[ -r "$HOME/.local/share/bash-completion/completions/herdr" ]] && source "$HOME/.local/share/bash-completion/completions/herdr"'
fi

# ~/venv with truss (Baseten model authoring / deploy-loop)
ensure_venv

echo "Setup complete!"
