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
# `apt-get update` may fail if not root / on non-Debian; tolerate that.
sudo apt-get update -y || apt-get update -y || true
sudo apt-get install -y btop || apt-get install -y btop || true

# Download and install/update nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash

# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"

# Download and install/update Node.js:
nvm install 26
nvm use 26

# Verify the Node.js version:
node -v # Should print "v26.2.0".

# Verify npm version:
npm -v # Should print "11.13.0".

# Install/update opencode
echo "Installing opencode..."
npm i -g opencode-ai

# Add opencode to PATH (idempotent)
append_once "$HOME/.bashrc" 'export PATH="$HOME/.opencode/bin:$PATH"'

# Configure opencode permissions
echo "Configuring opencode permissions..."
mkdir -p ~/.opencode
cat > ~/.opencode/opencode.json << 'JSONEOF'
{
  "permission": "allow"
}
JSONEOF

# Install/update croc
echo "Installing croc..."
curl -fsSL https://getcroc.schollz.com | bash

# Install/update gh
echo "Installing gh..."
curl -sS https://webi.sh/gh | sh

# Add gh to PATH (idempotent)
append_once "$HOME/.bashrc" 'export PATH="$HOME/.local/bin:$PATH"'

# Install/update uv
echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install/update Factory CLI
echo "Installing Factory CLI..."
curl -fsSL https://app.factory.ai/cli | sh

# Install/update Cursor CLI
# echo "Installing Cursor CLI..."
# curl https://cursor.com/install -fsS | bash

# Install/update paseo
echo "Installing paseo..."
npm install -g @getpaseo/cli && paseo

# Configure git identity for remote dev pods (idempotent)
echo "Configuring git identity..."
git config --global user.name "Dhruv Singal"
git config --global user.email "dhruvsingalabc@gmail.com"

echo "Setup complete!"
