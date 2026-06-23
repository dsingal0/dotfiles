#!/bin/bash
set -euo pipefail

# Install Homebrew if not present
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Taps
brew tap manaflow-ai/cmux

# Non-cask packages
brew install rtk

# Cask packages
brew install --cask cmux
brew install --cask cursor-cli
brew install --cask droid
brew install --cask paseo

echo "Done!"
