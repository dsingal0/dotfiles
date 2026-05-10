#!/usr/bin/env bash
set -euo pipefail

read -p "Are we in a kubectl pod? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  export HOME=/workspace/dsingal
  source ~/.bashrc
fi

# Install opencode
echo "Installing opencode..."
curl -fsSL https://opencode.ai/install | bash

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

# Configure git identity for remote dev pods
echo "Configuring git identity..."
git config --global user.name "Dhruv Singal"
git config --global user.email "dhruvsingalabc@gmail.com"

echo "Setup complete!"
