#!/usr/bin/env bash
# setup.sh - Linux (apt) bootstrap. Idempotent: re-run to install or update.
#
# Installs the apt toolchain, then hands off to bootstrap_common (lib/) for the
# shared omp/droid/factory/skills config. See lib/bootstrap.sh for the sequence.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/shared.sh"

# --- system packages (apt) ---------------------------------------------------
if command -v sudo >/dev/null 2>&1 && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  SUDO="sudo"; ADO="sudo DEBIAN_FRONTEND=noninteractive apt-get"
else
  SUDO=""; ADO="DEBIAN_FRONTEND=noninteractive apt-get"
fi
# DEBIAN_FRONTEND=noninteractive keeps package debconf questions (e.g.
# tzdata) from blocking; apt-get -y only covers apt's own confirmation.
# (sudo needs no guard: with no controlling tty it fails fast rather than
# block on a password prompt.)
# unzip is required by the bun installer (omp's binary needs bun).
$ADO update -y || true
$ADO install -y \
  btop unzip libclang-dev tree libevent-dev libncurses-dev build-essential bison tmux \
  || true
tmux -V

# --- gh (GitHub's official apt repo) ------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  echo "Installing gh..."
  $SUDO mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
  $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | $SUDO tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  $ADO update -y
  $ADO install -y gh
fi

# --- toolchain ---------------------------------------------------------------
install_node_nvm
install_uv
install_rust

# LIBCLANG_PATH for bindgen (Rust crates wrapping C/C++ libs).
for d in /usr/lib/llvm-*/lib; do
  if [[ -f "$d/libclang.so" ]]; then
    append_once "$HOME/.bashrc" "export LIBCLANG_PATH=\"$d\""
    break
  fi
done

# rtk (curl installer) — must precede bootstrap_common's configure_rtk.
export PATH="$HOME/.local/bin:$PATH"
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
rtk --version

# --- shared config + tools ---------------------------------------------------
# Design skills (frontend-design) + expo/emilkowalski packs are skipped on Linux
# dev pods; they are installed only by brew-setup.sh (macOS).
bootstrap_common "$SCRIPT_DIR" "frontend-design" false false

echo "Setup complete!"
