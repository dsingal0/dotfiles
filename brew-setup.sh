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
FORMULAS=(rtk)
CASKS=(cmux cursor-cli droid paseo)

# Install (no-op if already installed) then upgrade to latest
for pkg in "${FORMULAS[@]}"; do
  brew install "$pkg"
  brew upgrade "$pkg"
done

for pkg in "${CASKS[@]}"; do
  brew install --cask "$pkg"
  brew upgrade --cask "$pkg"
done

# Remove stale downloads and old versions
brew cleanup --prune=all

echo "Done!"
