#!/bin/bash
# brew-setup.sh - macOS (Homebrew) bootstrap. Idempotent.
#
# Installs formulae + casks, then hands off to bootstrap_common (lib/) for the
# shared omp/droid/factory/skills config, then the macOS-only bits (ghostty,
# baseten_aliases, casks, cleanup).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/shared.sh"

# --- Homebrew ------------------------------------------------------------------
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
brew update

# Taps + formulae. `node` provides npm (droid); `bun` is required by the omp
# binary; `baseten`/`uv`/`croc`/`rtk`/`gh`/`tmux` are the formulae route.
brew tap basetenlabs/baseten
brew trust basetenlabs/baseten 2>/dev/null || true
FORMULAS=(baseten btop bun croc gh node mole rtk tmux uv)
CASKS=(brave-browser@beta ghostty font-jetbrains-mono-nerd-font)
for pkg in "${FORMULAS[@]}"; do
  brew install "$pkg" || echo "Warning: failed to install formula '$pkg' (continuing)"
done

# --- shared config + tools -----------------------------------------------------
# Design skills + all third-party packs (emilkowalski + expo) are installed on macOS.
bootstrap_common "$SCRIPT_DIR" "" true true

# --- macOS-only config ----------------------------------------------------------
# Ghostty config (terminal font + SSH shell integration).
mkdir -p "$HOME/.config/ghostty"
ln -sf "$SCRIPT_DIR/ghostty.conf" "$HOME/.config/ghostty/config"

# Casks.
for pkg in "${CASKS[@]}"; do
  brew install --cask "$pkg" || echo "Warning: failed to install cask '$pkg' (continuing)"
done

# ~/.baseten_aliases: keep the managed `ksh` helper fresh, and keep a copy in the
# repo for version control.
ALIASES_FILE="$HOME/.baseten_aliases"
touch "$ALIASES_FILE"
write_managed_block "$ALIASES_FILE" \
  "# >>> ksh (managed by brew-setup.sh) >>>" \
  "# <<< ksh <<<" \
'ksh() {
  kubectl exec -it "$1" -- env TERM=xterm-256color COLORTERM=truecolor /bin/bash
}'
cp "$ALIASES_FILE" "$SCRIPT_DIR/baseten_aliases"

# Upgrade all installed packages + prune stale downloads.
echo "Checking for outdated packages..."
brew outdated --greedy || true
yes | brew upgrade || echo "Warning: brew upgrade failed (continuing)"
yes | brew upgrade --greedy || echo "Warning: brew upgrade --greedy failed (continuing)"
brew cleanup --prune=all || echo "Warning: brew cleanup failed (continuing)"

echo "Done!"
