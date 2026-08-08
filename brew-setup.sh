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
FORMULAS=(baseten btop croc gh node mole rtk tmux uv)
# iterm2 = terminal emulator. grok-build has no official curl installer, so it
# stays a cask; droid / opencode install via npm below, cursor-cli via curl.
CASKS=(brave-browser@beta iterm2)
CASKS+=(grok-build)

# Install (no-op if already installed). Continue on individual failures.
for pkg in "${FORMULAS[@]}"; do
  brew install "$pkg" || echo "Warning: failed to install formula '$pkg' (continuing)"
done

# Coding harnesses: opencode and droid install via npm (latest), grok-build is
# in the cask loop below and cursor-cli is further down.
# opencode defaults to the stable V1 (opencode-ai). Set OPENCODE_V2=1 to
# uninstall V1 and install the V2 beta (@opencode-ai/cli@next, runs as
# `opencode2`); allow-scripts covers its trusted postinstall binary selection.
npm config set allow-scripts="droid,opencode-ai,@opencode-ai/cli" --location=user
# Drop any opencode binary left by the old curl installer (~/.opencode/bin) so
# the npm-managed binary is the one on PATH.
rm -f "$HOME/.opencode/bin/opencode" 2>/dev/null || true
rmdir "$HOME/.opencode/bin" 2>/dev/null || true
echo "Installing opencode..."
if [[ "${OPENCODE_V2:-}" == "1" ]]; then
  npm uninstall -g opencode-ai || true
  npm install -g @opencode-ai/cli@next
  opencode2 --version 2>/dev/null || true
else
  npm i -g opencode-ai
  opencode --version
fi

# Drop the droid binary left by the old curl installer (~/.local/bin/droid) so
# the npm-managed binary is the one on PATH.
rm -f "$HOME/.local/bin/droid" 2>/dev/null || true
echo "Installing droid..."
npm install -g droid
droid --version 2>/dev/null || true

for pkg in "${CASKS[@]}"; do
  brew install --cask "$pkg" || echo "Warning: failed to install cask '$pkg' (continuing)"
done

# Install/update iTerm2 shell integration + utilities (iterm2 cask above).
echo "Installing iTerm2 shell integration..."
curl -L https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh | bash || true

# Upgrade all installed packages (formulae and casks)
echo "Checking for outdated packages..."
brew outdated --greedy || true
yes | brew upgrade || echo "Warning: brew upgrade failed (continuing)"
yes | brew upgrade --greedy || echo "Warning: brew upgrade --greedy failed (continuing)"

# Symlink tmux config (enables mouse scroll passthrough for Droid in tmux)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ln -sf "$SCRIPT_DIR/tmux.conf" "$HOME/.tmux.conf"

# Link custom user scripts into ~/.local/bin
mkdir -p "$HOME/.local/bin"
ln -sf "$SCRIPT_DIR/bin/droid-export" "$HOME/.local/bin/droid-export"
ln -sf "$SCRIPT_DIR/bin/devpod-bundle" "$HOME/.local/bin/devpod-bundle"
export PATH="$HOME/.local/bin:$PATH"

# Source shared config helpers (opencode permission + Baseten BYOK models),
# deduplicated with setup.sh so both bootstrap scripts stay in sync.
. "$SCRIPT_DIR/lib/shared.sh"

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

# Install cursor-cli (Cursor agent) via official installer
echo "Installing cursor-cli..."
curl -fsS https://cursor.com/install | bash
cursor --version 2>/dev/null || true

# droid is installed via npm above

# Configure Factory: Baseten BYOK custom models (~/.factory/settings.json) and
# FACTORY_API_KEY exported to shell rc files for the droid CLI.
# Keys are read from .env in the repo root (kept local, never committed).
# Copy .env.example to .env and fill in your keys:
#   cp .env.example .env
# Keys can also be exported directly: BASETEN_API_KEY=... FACTORY_API_KEY=... ./brew-setup.sh
configure_factory "$SCRIPT_DIR"
configure_cursor

# Install personal skills into every harness (droid / opencode / cursor / grok)
install_shared_skills "$SCRIPT_DIR"

# Third-party skill packs (mattpocock + basetenlabs + emilkowalski) for all agents
install_skill_packages true

# baseten CLI is installed via the FORMULAS brew loop above; ensure version prints
baseten --version 2>/dev/null || baseten version 2>/dev/null || true

# ~/venv with truss (Baseten model authoring / deploy-loop)
ensure_venv

# Install paseo CLI via npm (pre-release track via the `beta` dist-tag, latest npm from brew's node formula)
npm install -g --allow-scripts=node-pty @getpaseo/cli@beta

# Remove stale downloads and old versions
brew cleanup --prune=all || echo "Warning: brew cleanup failed (continuing)"

echo "Done!"
