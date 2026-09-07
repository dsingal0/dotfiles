# dotfiles

Personal dotfiles and bootstrap scripts for spinning up a new dev machine,
remote dev pod, or any fresh box with the same tools and config as this one.

Three platform bootstrap scripts share a common config layer in `lib/shared.sh`:

- **`setup.sh`** - Linux / apt-based dev pods.
- **`setup-arch.sh`** - Arch Linux (pacman + paru/AUR).
- **`brew-setup.sh`** - macOS (Homebrew).

All three are idempotent: re-run them to install or update tools on an
existing machine. Run the one for your platform.

## Setup

```bash
git clone https://github.com/dsingal0/dotfiles ~/dotfiles
cd ~/dotfiles

# Linux (apt-based):
./setup.sh

# Arch Linux (pacman + paru/AUR):
./setup-arch.sh

# macOS (Homebrew):
./brew-setup.sh
```

### Baseten API key (used by omp, droid, and Factory custom models)

Wires Baseten-hosted models into the omp provider config
(`~/.omp/agent/models.yml`) and Factory droid custom models
(`~/.factory/settings.json`). Provide an API key:

```bash
cp .env.example .env
# edit .env and set BASETEN_API_KEY=...
./setup.sh   # or ./brew-setup.sh / ./setup-arch.sh
```

Without a key, the relevant step is skipped with a warning.

### Factory API key (optional)

`FACTORY_API_KEY` authenticates the `droid` CLI via an env var instead of the
default OAuth file (`~/.factory/auth.v2.file`). When set in `.env`, the setup
script persists `export FACTORY_API_KEY=...` into `~/.bashrc` (and `~/.zshrc` if
present), so:

- **new shells** get it automatically,
- **existing shells** need `source ~/.bashrc` (or a new terminal).

Keys live in `.env` (tracked; the repo is private) and are embedded into the
generated harness configs at setup time.

## Repository layout

```
.
├── setup.sh           # Linux bootstrap (apt, nvm, rust, droid, omp, ...)
├── setup-arch.sh      # Arch Linux bootstrap (pacman + paru/AUR, same toolchain)
├── brew-setup.sh      # macOS bootstrap (Homebrew formulae + casks)
├── lib/
│   └── shared.sh      # sourced by all bootstraps: omp installer + model
│                      #   config, skills, runlayer MCP, Baseten BYOK models
├── bin/
│   └── devpod-bundle  # pack/restore SSH + omp/factory/cursor/grok/truss
│                      #   auth+settings for Mac <-> dev pod sync
├── devpod-bundle -> bin/devpod-bundle   (run from repo root on any host)
├── clone_runtimes.sh  # shallow-clone the Baseten/vLLM/TensorRT-LLM repos into ~/repos
├── config/
│   └── omp/
│       └── AGENTS.md  # global omp rules, symlinked into ~/.omp/agent
├── skills/            # personal skills, symlinked into every agent harness
├── baseten_aliases    # kubectl / shell aliases for the baseten monorepo
├── tmux.conf          # symlinked to ~/.tmux.conf
├── ghostty.conf       # symlinked to ~/.config/ghostty/config (macOS)
├── .env.example       # template for BASETEN_API_KEY / FACTORY_API_KEY / ...
├── dsingal-dev-pod-b300.yaml  # dev pod spec
└── README.md
```

## What gets installed

### Both platforms (via `lib/shared.sh`)

- **omp** (oh-my-pi, `@oh-my-pi/pi-coding-agent`), the coding harness: vanilla
  setup — no custom agents, no plugins. `configure_omp` writes
  `~/.omp/agent/models.yml` (Baseten provider + OpenRouter free floor,
  requires `BASETEN_API_KEY`) and `~/.omp/agent/config.yml` (model roles +
  the 7-model fallback chain, Flash head). The repo's global rules are
  symlinked to `~/.omp/agent/AGENTS.md`.
- **droid** (Factory CLI) via npm, with Baseten BYOK custom models written to
  `~/.factory/settings.json` (requires `BASETEN_API_KEY`).
- **FACTORY_API_KEY** and **FACTORY_DISABLE_KEYRING=1** persisted to shell rc
  files so droid stores auth in the portable `~/.factory/auth.v2.file` +
  `auth.v2.key` pair instead of the macOS login keychain.
- **runlayer MCP** configured in omp, droid, and cursor.
- **git identity** (name + email) configured globally.
- **rtk** (Rust Token Killer - LLM token proxy), initialized for omp
  (Pi coding agent) and Cursor (preToolUse hook). Note: rtk has no native
  Droid/Factory integration; Droid is not wired here.
- **~/venv** (via `uv`) with **truss** (Baseten model authoring / deploy-loop).
- Personal skills from the repo's `skills/` directory, symlinked into every
  harness (`~/.factory/skills/`, `~/.omp/agent/skills/`,
  `~/.cursor/skills/`, and `~/.grok/skills/` on macOS). Design skills
  (`frontend-design`) are skipped on Linux dev pods and installed only by
  `brew-setup.sh`. Third-party packs (mattpocock, expo, emilkowalski on
  macOS) are installed via the `skills` CLI into `~/.agents/skills/`
  (`universal`), which omp reads natively.

### Linux (`setup.sh`)

- **btop**, tree, build-essential, libclang-dev (best-effort via apt)
- **tmux** (distro package), config symlinked to `~/.tmux.conf`
- **nvm** + latest Node.js (`nvm install node`, never pinned)
- **gh** (GitHub CLI, via GitHub's official apt repo)
- **uv** (Python package manager)
- **Rust** / Cargo (+ `LIBCLANG_PATH` for bindgen)
- **rtk** (curl installer)
- **croc** (file transfer, GitHub release binary)

### Arch Linux (`setup-arch.sh`)

Same toolchain as `setup.sh`, with system packages from pacman / AUR instead of
apt:

- **base-devel**, git, **btop**, clang, tree, libevent, ncurses, bison,
  **tmux**, **gh** (as `github-cli`), **croc**, **uv** (best-effort via pacman)
- **paru** (AUR helper, built from the AUR if missing)
- **rtk** (via AUR `rtk-bin`, falling back to the official curl installer)

### macOS (`brew-setup.sh`)

- Homebrew formulae: `baseten btop croc gh node mole rtk tmux uv`
- Homebrew casks: `brave-browser@beta ghostty font-jetbrains-mono-nerd-font grok-build`
- **droid** (npm) and **cursor-cli** (official curl installer)
- `~/.baseten_aliases` created if missing; the managed `ksh` shell helper is
  (re)written and a copy kept in the repo for version control
- `brew cleanup --prune=all` at the end

## tmux config (`tmux.conf`)

Tuned for running TUI agents (omp, droid) inside tmux, including over SSH
to remote pods. Symlinked to `~/.tmux.conf` by both setup scripts. Highlights:

- **mouse on** - wheel events pass through to mouse-tracking TUIs
- **extended-keys** with CSI-u (tmux 3.3+ guarded, so 3.2a doesn't error)
- **256-color + RGB** for `xterm-256color` (Ghostty)
- **escape-time 0** - responsive modal editors
- **focus-events on** - editors/watchers get focus/blur
- **history-limit 100000** - long agent transcripts reachable in copy mode
- **renumber-windows on** - compact window numbers
- **set-clipboard on** - OSC 52 clipboard passthrough to the local machine over SSH

## droid-export

Export a Factory "droid" session transcript to a portable, harness-agnostic
format. A droid session lives at `~/.factory/sessions/<encoded-cwd>/<session-id>.jsonl`.

## devpod-bundle (`bin/devpod-bundle`)

Pack the auth + settings for SSH, omp, Factory droid, Cursor CLI, grok
CLI, and truss (Baseten) into one tar.gz, croc it to a dev pod, and restore it
there - so you only stay logged in on one machine (your Mac).

Paths in the archive are relative to `$HOME`, so restore works on any pod
regardless of username.

**omp** config travels via `~/.omp/agent/models.yml` (Baseten key inline),
`config.yml` (roles + fallback chain), and `mcp.json`; `--restore` verifies
the inline apiKey landed. Skills and the `AGENTS.md` symlink come from the
dotfiles repo on the pod, not from this bundle.

**Cursor CLI** auth is file-based: set `AGENT_CLI_CREDENTIAL_STORE=file` so
`cursor-agent` writes `~/.cursor/auth.json` on macOS (and reads
`~/.config/cursor/auth.json` on Linux). That file IS bundled; on restore it is
copied to `~/.config/cursor/auth.json` on Linux.
`~/.cursor/env` (`CURSOR_API_KEY`) is also bundled and sourced by shell rc, but
it is legacy - the current `cursor-agent` binary does not read `CURSOR_API_KEY`.

**Factory droid** auth is file-based too: set `FACTORY_DISABLE_KEYRING=1` so
droid writes the portable `~/.factory/auth.v2.file` + `auth.v2.key` pair instead
of the macOS login keychain (`auth.v2.loginkeychain`, which is NOT portable to
Linux). The `auth.v2.file`/`auth.v2.key` pair IS bundled. The factory mTLS cert
(`~/.factory/cache/certs/factory-cli-certs.pem`) is bundled; re-run
`factory login` on the pod if it has expired. Truss (Baseten) credentials
(`~/.trussrc`) are bundled too; re-run `truss login` on the pod if a remote
needs re-auth.

```bash
# On the Mac (the machine you stay logged in on):
devpod-bundle                          # writes ~/devpod-bundle-<stamp>.tar.gz
devpod-bundle --list                   # dry run, write nothing
devpod-bundle -o /tmp/x.tgz            # custom output path
croc send ~/devpod-bundle-*.tar.gz

# On the dev pod (after `git pull` of this repo at ~/dotfiles):
~/dotfiles/devpod-bundle --restore ~/devpod-bundle-*.tar.gz
~/dotfiles/devpod-bundle --restore ~/devpod-bundle-*.tar.gz --dry-run  # list only
# or, without the script: cd ~ && tar -xzf devpod-bundle-*.tar.gz
```

## Notes

- The only coding harnesses installed are **omp**, **droid**
  (Factory CLI), **cursor-cli**, and **grok-build** (macOS only, Homebrew
  cask - it has no curl installer).
- Herdr bash completions are regenerated on Linux if `herdr` is present
  (Herdr itself is installed out-of-band).
