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
brew tap basetenlabs/baseten
# Third-party taps may require an explicit trust step on newer Homebrew.
brew trust basetenlabs/baseten 2>/dev/null || true

# Packages to install and keep up to date
# `node` provides npm, used below to install paseo.
# `baseten` = basetenlabs/baseten-cli (https://github.com/basetenlabs/baseten-cli); `uv` for ~/venv + truss.
FORMULAS=(baseten btop croc gh node mole pnpm rtk tmux uv)
# ghostty = terminal emulator. grok-build has no official curl installer, so it
# stays a cask; droid / opencode install via pnpm below, cursor-cli via curl.
# font-jetbrains-mono-nerd-font = JetBrains Mono with Nerd Font glyphs for TUIs.
CASKS=(brave-browser@beta ghostty font-jetbrains-mono-nerd-font)
CASKS+=(grok-build)

# Install (no-op if already installed). Continue on individual failures.
for pkg in "${FORMULAS[@]}"; do
  brew install "$pkg" || echo "Warning: failed to install formula '$pkg' (continuing)"
done

# Source shared config helpers (opencode install + permission config, Baseten
# BYOK models), deduplicated with setup.sh so both bootstrap scripts stay in
# sync. Sourcing only defines functions, so it is safe to do this early.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/shared.sh"

# pnpm global binaries live in $PNPM_HOME/bin; ensure that dir is on PATH for
# the pnpm-based installs below. (`pnpm bin -g` errors out when the dir isn't
# already on PATH, so derive it from the platform default instead.)
case "$(uname -s)" in
  Darwin) PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}" ;;
  *)      PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}" ;;
esac
export PNPM_HOME
export PATH="$PNPM_HOME/bin:$PATH"

# Uninstall the npm-managed copies of packages now handled by pnpm, so no
# stale npm binaries linger on PATH.
npm uninstall -g opencode-ai @opencode-ai/cli droid @getpaseo/cli 2>/dev/null || true

# Coding harnesses: opencode and droid install via pnpm (latest), grok-build is
# in the cask loop below and cursor-cli is further down.
# Drop any opencode binary left by the old curl installer (~/.opencode/bin) so
# the pnpm-managed binary is the one on PATH.
rm -f "$HOME/.opencode/bin/opencode" 2>/dev/null || true
rmdir "$HOME/.opencode/bin" 2>/dev/null || true

# Uninstall opencode v1 (opencode-ai) so it cannot shadow v2 on PATH.
echo "Uninstalling opencode (v1)..."
pnpm remove -g opencode-ai 2>/dev/null || true

install_opencode_v2

# Install/update Meta CLI.
curl -fsSL https://dev.meta.ai/install.sh | bash

# Drop the droid binary left by the old curl installer (~/.local/bin/droid) so
# the pnpm-managed binary is the one on PATH.
rm -f "$HOME/.local/bin/droid" 2>/dev/null || true
echo "Installing droid..."
pnpm add -g --allow-build=droid droid
droid --version 2>/dev/null || true

for pkg in "${CASKS[@]}"; do
  brew install --cask "$pkg" || echo "Warning: failed to install cask '$pkg' (continuing)"
done

# Upgrade all installed packages (formulae and casks)
echo "Checking for outdated packages..."
brew outdated --greedy || true
yes | brew upgrade || echo "Warning: brew upgrade failed (continuing)"
yes | brew upgrade --greedy || echo "Warning: brew upgrade --greedy failed (continuing)"

# Symlink tmux config (enables mouse scroll passthrough for Droid in tmux)
ln -sf "$SCRIPT_DIR/tmux.conf" "$HOME/.tmux.conf"

# Symlink Ghostty config (terminal font + SSH shell integration)
mkdir -p "$HOME/.config/ghostty"
ln -sf "$SCRIPT_DIR/ghostty.conf" "$HOME/.config/ghostty/config"

# Link custom user scripts into ~/.local/bin
mkdir -p "$HOME/.local/bin"
rm -f "$HOME/.local/bin/droid-export"
ln -sf "$SCRIPT_DIR/bin/devpod-bundle" "$HOME/.local/bin/devpod-bundle"
export PATH="$HOME/.local/bin:$PATH"

ensure_pnpm_shell_path

# Manage ~/.baseten_aliases (create if missing) and ensure the `ksh` shell helper
# is defined. Keeps a copy in the dotfiles repo for version control.
ALIASES_FILE="$HOME/.baseten_aliases"
python3 - "$ALIASES_FILE" << 'PYEOF'
import re, sys

path = sys.argv[1]
try:
    with open(path, "r") as f:
        content = f.read()
except FileNotFoundError:
    content = ""

ksh_block = '''# >>> ksh (managed by brew-setup.sh) >>>
ksh() {
  kubectl exec -it "$1" -- env TERM=xterm-256color COLORTERM=truecolor /bin/bash
}
# <<< ksh <<<'''

# Replace any existing managed block (or remove a stale one), then append fresh
content = re.sub(r'\n?# >>> ksh \(managed by brew-setup\.sh\) >>>.*?# <<< ksh <<<\n?', '\n', content, flags=re.DOTALL)
content = content.rstrip()
if content:
    content += "\n\n"
content += ksh_block + "\n"

with open(path, "w") as f:
    f.write(content)
PYEOF

# Keep a copy in the dotfiles repo
cp "$ALIASES_FILE" "$SCRIPT_DIR/baseten_aliases"

# opencode itself is installed above, before the other coding harnesses.
configure_opencode_permission

# Install the repo's global opencode instructions (~/.config/opencode/AGENTS.md)
# so every project session follows the same global rules.
install_global_agents_md "$SCRIPT_DIR"

# Install cursor-cli (Cursor agent) via official installer
echo "Installing cursor-cli..."
curl -fsS https://cursor.com/install | bash
cursor --version 2>/dev/null || true

# droid is installed via pnpm above

# Configure Factory: Baseten BYOK custom models (~/.factory/settings.json) and
# FACTORY_API_KEY exported to shell rc files for the droid CLI.
# Keys are read from .env in the repo root (kept local, never committed).
# Copy .env.example to .env and fill in your keys:
#   cp .env.example .env
# Keys can also be exported directly: BASETEN_API_KEY=... FACTORY_API_KEY=... ./brew-setup.sh
configure_factory "$SCRIPT_DIR"
configure_cursor

# Remove the stale third-party baseten skill (basetenlabs/baseten-skills) so the
# repo's static, pruned, BIS-focused copy (skills/baseten/) gets symlinked in
# its place by install_shared_skills below.
cleanup_stale_baseten_skill

# Install personal skills into every harness (droid / opencode / cursor / grok)
install_shared_skills "$SCRIPT_DIR"

# Third-party skill packs (mattpocock + emilkowalski) for all agents. The baseten
# skill is no longer pulled from basetenlabs/baseten-skills (out of date); it
# lives as a static copy in this repo under skills/baseten/ (installed above).
install_skill_packages true

# baseten CLI is installed via the FORMULAS brew loop above; ensure version prints
baseten --version 2>/dev/null || baseten version 2>/dev/null || true

# ~/venv with truss (Baseten model authoring / deploy-loop)
ensure_venv

# Install paseo CLI via pnpm (pre-release track via the `beta` dist-tag, latest npm from brew's node formula)
# --allow-build: native postinstall deps; without these, pnpm prompts interactively.
pnpm add -g --allow-build=node-pty --allow-build=@parcel/watcher @getpaseo/cli@beta

# Remove stale downloads and old versions
brew cleanup --prune=all || echo "Warning: brew cleanup failed (continuing)"

echo "Done!"
