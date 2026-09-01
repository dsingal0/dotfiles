#!/usr/bin/env bash
# Uninstall jcode and carry from this machine (2026-09: stack moved to
# opencode v2 + oh-my-opencode-slim). Run manually — it removes home-dir
# paths the agent is not allowed to touch.
set -x

# 1. brew-managed jcode (1jehuang/jcode tap)
brew uninstall jcode 2>/dev/null
brew untap 1jehuang/jcode 2>/dev/null

# 2. Locally built binaries
rm -f "$HOME/.local/bin/jcode" "$HOME/.local/bin/carry"

# 3. Config / data dirs
rm -rf "$HOME/.jcode" "$HOME/.carry"

# 4. Repos (optional — comment out to keep source)
# rm -rf "$HOME/repos/jcode" "$HOME/repos/remote_agent"

echo "=== verify ==="
command -v jcode || echo "jcode: gone"
command -v carry || echo "carry: gone"
ls "$HOME/.jcode" 2>/dev/null || echo "~/.jcode: gone"
ls "$HOME/.carry" 2>/dev/null || echo "~/.carry: gone"
