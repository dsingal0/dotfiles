#!/usr/bin/env bash
set -euo pipefail

# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash

# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"

# Download and install Node.js:
nvm install 26

# Verify the Node.js version:
node -v # Should print "v26.2.0".

# Verify npm version:
npm -v # Should print "11.13.0".

# Install opencode
echo "Installing opencode..."
curl -fsSL https://opencode.ai/install | bash

npm i -g opencode-ai

# Configure opencode permissions
echo "Configuring opencode permissions..."
mkdir -p ~/.opencode
cat > ~/.opencode/opencode.json << 'JSONEOF'
{
  "permission": "allow"
}
JSONEOF

# Install croc
echo "Installing croc..."
curl -fsSL https://getcroc.schollz.com | bash

# Install gh
echo "Installing gh..."
curl -sS https://webi.sh/gh | sh

# Install uv
echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install paseo
echo "Installing paseo..."
npm install -g @getpaseo/cli && paseo

# Configure git identity for remote dev pods
echo "Configuring git identity..."
git config --global user.name "Dhruv Singal"
git config --global user.email "dhruvsingalabc@gmail.com"

echo "Setup complete!"
