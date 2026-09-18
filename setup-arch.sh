#!/usr/bin/env bash
# setup-arch.sh - Arch Linux (pacman + paru/AUR) bootstrap. Idempotent.
#
# Same toolchain as setup.sh but system packages come from pacman / AUR. Hands
# off to bootstrap_common (lib/) for the shared omp/droid/factory/skills config.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/shared.sh"

# --- system packages (pacman) --------------------------------------------------
if command -v sudo >/dev/null 2>&1 && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi
$SUDO pacman -Syu --noconfirm || true
# Debian -> Arch mapping: build-essential->base-devel, libclang-dev->clang,
# libevent-dev->libevent, libncurses-dev->ncurses, gh->github-cli.
$SUDO pacman -S --needed --noconfirm \
  base-devel git btop unzip clang tree libevent ncurses bison tmux github-cli croc uv \
  || true
tmux -V

# paru (AUR helper) for AUR-only packages below; makepkg must run non-root.
if ! command -v paru >/dev/null 2>&1 && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Installing paru (AUR helper)..."
  build_dir="$HOME/.cache/paru-build"
  rm -rf "$build_dir"; mkdir -p "$(dirname "$build_dir")"
  git clone https://aur.archlinux.org/paru.git "$build_dir"
  ( cd "$build_dir" && makepkg -si --noconfirm )
  rm -rf "$build_dir"; hash -r
fi

# --- toolchain ---------------------------------------------------------------
install_node_nvm
# uv + croc are pacman packages above; ensure ~/.local/bin is on PATH.
export PATH="$HOME/.local/bin:$PATH"
# shellcheck disable=SC1091
\. "$HOME/.local/bin/env" 2>/dev/null || true
install_rust

# LIBCLANG_PATH for bindgen — Arch's clang puts libclang.so in /usr/lib.
if [[ -f /usr/lib/libclang.so ]]; then
  append_once "$HOME/.bashrc" 'export LIBCLANG_PATH="/usr/lib"'
fi

# rtk via AUR (rtk-bin), falling back to the official curl installer.
export PATH="$HOME/.local/bin:$PATH"
echo "Installing rtk..."
if command -v paru >/dev/null 2>&1; then
  paru -S --needed --noconfirm rtk-bin \
    || curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
else
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
fi
rtk --version

# --- shared config + tools ---------------------------------------------------
# Design skills (frontend-design) + expo/emilkowalski packs are skipped on Linux
# dev pods; they are installed only by brew-setup.sh (macOS).
bootstrap_common "$SCRIPT_DIR" "frontend-design" false false

echo "Setup complete!"
