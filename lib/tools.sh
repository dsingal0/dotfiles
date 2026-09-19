# tools.sh - tool installers shared by every bootstrap script.
#
# Sourced by lib/shared.sh; not executable on its own.

# --- shared helpers -----------------------------------------------------------

# Download + install a binary from a GitHub release tarball into ~/.local/bin.
#   _gh_binary <bin> <owner>/<repo> <os> <arch> <asset_fmt>
# <asset_fmt> is a printf template for "<ver> <os> <arch>" (ver has no leading v).
_gh_binary() {
  local bin="$1" repo="$2" os="$3" arch="$4" fmt="$5"
  local tag ver asset url tmp
  tag="$(gh_latest_tag "$repo")"
  if [[ -z "$tag" ]]; then
    echo "WARNING: could not resolve the latest $repo release; skipping $bin."
    return 0
  fi
  ver="${tag#v}"
  asset="$(printf "$fmt" "$ver" "$os" "$arch")"
  url="https://github.com/$repo/releases/download/$tag/$asset"

  mkdir -p "$HOME/.local/bin"
  tmp="$(mktemp -d)"
  echo "  downloading $url ..."
  if curl -fsSL "$url" | tar xz -C "$tmp" && [[ -f "$tmp/$bin" ]]; then
    install -m 755 "$tmp/$bin" "$HOME/.local/bin/$bin"
    export PATH="$HOME/.local/bin:$PATH"
    "$bin" --version 2>/dev/null || "$bin" version 2>/dev/null || true
  else
    echo "WARNING: failed to download/install $bin from $url"
  fi
  rm -rf "$tmp"
}

# --- language toolchains (Linux bootstraps) ------------------------------------

# nvm + latest Node.js (never pinned).
install_node_nvm() {
  echo "Installing nvm + node..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
  append_once "$HOME/.bashrc" 'export NVM_DIR="$HOME/.nvm"'
  append_once "$HOME/.bashrc" '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
  \. "$HOME/.nvm/nvm.sh"
  nvm install node
  nvm use node
  node -v
}

# Rust + Cargo via rustup.
install_rust() {
  echo "Installing Rust..."
  if command -v rustup >/dev/null 2>&1; then
    rustup update stable
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  \. "$HOME/.cargo/env" 2>/dev/null || true
  rustc --version; cargo --version
}

# uv (Python package manager).
install_uv() {
  echo "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  # shellcheck disable=SC1091
  \. "$HOME/.local/bin/env" 2>/dev/null || true
}

# --- individual tools ----------------------------------------------------------

# Install droid (Factory CLI). npm always runs postinstall, so the npm-managed
# install is the reliable one. Drops any stale curl/npm-managed copies first.
install_droid() {
  npm uninstall -g droid @getpaseo/cli 2>/dev/null || true
  rm -f "$HOME/.local/bin/droid" 2>/dev/null || true
  echo "Installing droid..."
  npm install -g droid
  droid --version 2>/dev/null || true
}

# Install the Baseten CLI (https://github.com/basetenlabs/baseten-cli).
# Prefers Homebrew; falls back to the latest GitHub release tarball.
install_baseten_cli() {
  echo "Installing baseten CLI..."
  if command -v brew >/dev/null 2>&1; then
    brew tap basetenlabs/baseten
    brew trust basetenlabs/baseten 2>/dev/null || true
    brew install baseten </dev/null
    baseten --version 2>/dev/null || baseten version 2>/dev/null || true
    return 0
  fi
  local os arch
  case "$(uname -s)" in
    Darwin) os="darwin" ;; Linux) os="linux" ;;
    *) echo "WARNING: unsupported OS for baseten CLI: $(uname -s)"; return 0 ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch="arm64" ;; x86_64|amd64) arch="amd64" ;;
    *) echo "WARNING: unsupported arch for baseten CLI: $(uname -m)"; return 0 ;;
  esac
  _gh_binary baseten basetenlabs/baseten-cli "$os" "$arch" 'baseten_%s_%s_%s.tar.gz'
}

# Install croc (https://github.com/schollz/croc). Prefers Homebrew; falls back
# to the latest GitHub release tarball. Skipped when croc is already present
# (e.g. a distro package on Arch).
ensure_croc() {
  echo "Installing croc..."
  if command -v brew >/dev/null 2>&1; then
    brew install croc </dev/null
    croc --version 2>/dev/null || true
    return 0
  fi
  local os arch
  case "$(uname -s)" in
    Darwin) os="macOS" ;; Linux) os="Linux" ;;
    *) echo "WARNING: unsupported OS for croc: $(uname -s)"; return 0 ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch="ARM64" ;; x86_64|amd64) arch="64bit" ;;
    *) echo "WARNING: unsupported arch for croc: $(uname -m)"; return 0 ;;
  esac
  _gh_binary croc schollz/croc "$os" "$arch" 'croc_v%s_%s-%s.tar.gz'
}

# Ensure uv is available, create ~/venv if missing, and install/upgrade
# truss + magic-wormhole into it. wormhole is symlinked into ~/.local/bin.
ensure_venv() {
  echo "Ensuring ~/venv with truss and magic-wormhole..."
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
  if ! command -v uv >/dev/null 2>&1; then
    echo "  uv not found; installing via astral.sh..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
  if ! command -v uv >/dev/null 2>&1; then
    echo "WARNING: uv still not on PATH; cannot create ~/venv."
    return 0
  fi
  [[ -x "$HOME/venv/bin/python" ]] || uv venv "$HOME/venv"
  uv pip install --python "$HOME/venv/bin/python" --upgrade truss magic-wormhole
  if [[ -x "$HOME/venv/bin/truss" ]]; then
    echo "  truss: $("$HOME/venv/bin/truss" version 2>/dev/null || "$HOME/venv/bin/python" -c 'import truss; print(getattr(truss, "__version__", "installed"))')"
  fi
  if [[ -x "$HOME/venv/bin/wormhole" ]]; then
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$HOME/venv/bin/wormhole" "$HOME/.local/bin/wormhole"
    echo "  wormhole: $("$HOME/venv/bin/wormhole" --version 2>/dev/null || echo installed)"
  fi
  echo "  venv ready at $HOME/venv (activate with: source ~/venv/bin/activate)"
}

# Regenerate Herdr bash completions (herdr is installed out-of-band). No-op
# when herdr is absent.
install_herdr_completions() {
  command -v herdr >/dev/null 2>&1 || return 0
  echo "Installing Herdr bash completions..."
  mkdir -p "$HOME/.local/share/bash-completion/completions"
  herdr completion bash > "$HOME/.local/share/bash-completion/completions/herdr"
  append_once "$HOME/.bashrc" '# Herdr bash completions (managed by dotfiles setup)'
  append_once "$HOME/.bashrc" '[[ -r "$HOME/.local/share/bash-completion/completions/herdr" ]] && source "$HOME/.local/share/bash-completion/completions/herdr"'
}

# Symlink the repo's bin scripts + config into place. Pass the repo root.
link_repo_files() {
  local repo_dir="$1"
  mkdir -p "$HOME/.local/bin"
  rm -f "$HOME/.local/bin/droid-export"
  ln -sf "$repo_dir/bin/devpod-bundle" "$HOME/.local/bin/devpod-bundle"
  ln -sf "$repo_dir/tmux.conf" "$HOME/.tmux.conf"
}
