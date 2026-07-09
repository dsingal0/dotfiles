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
brew tap manaflow-ai/cmux

# Packages to install and keep up to date
# `node` provides npm, used below to install opencode.
FORMULAS=(croc gh node mole rtk tmux)
CASKS=(brave-browser@beta cmux cursor-cli)

# Install (no-op if already installed)
for pkg in "${FORMULAS[@]}"; do
  brew install "$pkg"
done

for pkg in "${CASKS[@]}"; do
  brew install --cask "$pkg"
done

# Upgrade all installed packages (formulae and casks)
echo "Checking for outdated packages..."
brew outdated --greedy || true
brew upgrade
brew upgrade --greedy

# Symlink tmux config (enables mouse scroll passthrough for Droid in tmux)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ln -sf "$SCRIPT_DIR/tmux.conf" "$HOME/.tmux.conf"

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

# Install/update opencode (stable)
echo "Installing opencode..."
npm i -g opencode-ai
opencode --version

configure_opencode_permission

# Install droid via npm (was previously a brew cask)
npm config set allow-scripts="droid,opencode-ai" --location=user
npm install -g droid

# Configure Factory: Baseten BYOK custom models (~/.factory/settings.json) and
# FACTORY_API_KEY exported to shell rc files for the droid CLI.
# Keys are read from .env in the repo root (kept local, never committed).
# Copy .env.example to .env and fill in your keys:
#   cp .env.example .env
# Keys can also be exported directly: BASETEN_API_KEY=... FACTORY_API_KEY=... ./brew-setup.sh
configure_factory "$SCRIPT_DIR"

# Install paseo CLI via npm (pre-release track via the `beta` dist-tag, latest npm from brew's node formula)
npm install -g @getpaseo/cli@beta

# Install Devin CLI
echo "Installing Devin CLI..."
curl -fsSL https://cli.devin.ai/install.sh | bash

# Remove stale downloads and old versions
brew cleanup --prune=all

echo "Done!"
