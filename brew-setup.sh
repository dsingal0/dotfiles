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
  # NONINTERACTIVE skips the installer's "Press RETURN/ENTER" prompt. Creating
  # /opt/homebrew still needs sudo: it prompts on the tty when one is present
  # and fails fast when there isn't one.
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
brew update

# Non-interactive operation from here on:
# - HOMEBREW_NO_AUTO_UPDATE: `brew update` above is the one metadata refresh;
#   without this every install/upgrade can trigger a mid-command auto-update.
# - HOMEBREW_NO_INSTALL_CLEANUP: one `brew cleanup` at the end instead of a
#   cleanup pass after every install.
# (No sudo guard needed: brew runs plain `sudo`, which prompts on /dev/tty
# when a terminal exists and fails fast when it doesn't — it can't hang.)
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1

# Taps + formulae. `node` provides npm (droid); `bun` is required by the omp
# binary; `baseten`/`uv`/`croc`/`rtk`/`gh`/`tmux` are the formulae route.
brew tap basetenlabs/baseten
brew trust basetenlabs/baseten 2>/dev/null || true
FORMULAS=(baseten btop bun croc gh node mole rtk tmux uv)
CASKS=(brave-browser@beta ghostty font-jetbrains-mono-nerd-font)
for pkg in "${FORMULAS[@]}"; do
  brew install "$pkg" </dev/null || echo "Warning: failed to install formula '$pkg' (continuing)"
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
  brew install --cask "$pkg" </dev/null || echo "Warning: failed to install cask '$pkg' (continuing)"
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

# Upgrade all installed packages + prune stale downloads. One package per
# invocation: a single failure can't fail the whole batch, and every warning
# names its package. No `yes |` — brew has no y/N prompts during upgrade and
# sudo (the only possible prompt) reads /dev/tty, which `yes` can't answer.
# --greedy also pulls casks that self-update.
echo "Checking for outdated packages..."
brew outdated --greedy || true
while read -r pkg; do
  # </dev/null: keeps brew from eating the loop's stdin (the package list)
  # and guarantees nothing inside can block waiting on input.
  brew upgrade "$pkg" </dev/null || echo "Warning: failed to upgrade '$pkg' (continuing)"
done < <(brew outdated --greedy --quiet || true)
brew cleanup --prune=all || echo "Warning: brew cleanup failed (continuing)"

echo "Done!"
