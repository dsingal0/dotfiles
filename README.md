# dotfiles

Personal dotfiles and bootstrap scripts for spinning up a new dev machine,
remote dev pod, or any fresh box with the same tools and config as this one.

Three platform bootstrap scripts share a common config layer in `lib/shared.sh`:

- **`setup.sh`** - Linux / apt-based dev pods.
- **`setup-arch.sh`** - Arch Linux (pacman + paru/AUR).
- **`brew-setup.sh`** - macOS (Homebrew).

Both are idempotent: re-run them to install or update tools on an existing
machine. Run the one for your platform.

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

### Baseten BYOK (optional)

To wire custom Baseten-hosted models into Factory (`~/.factory/settings.json`),
provide an API key:

```bash
cp .env.example .env
# edit .env and set BASETEN_API_KEY=...
./setup.sh   # or ./brew-setup.sh
```

### Factory API key (optional)

`FACTORY_API_KEY` authenticates the `droid` CLI via an env var instead of the
default OAuth file (`~/.factory/auth.v2.file`). When set in `.env`, the setup
script persists `export FACTORY_API_KEY=...` into `~/.bashrc` (and `~/.zshrc` if
present) inside a managed block, so:

- **new shells** get it automatically,
- **existing shells** need `source ~/.bashrc` (or a new terminal).

Leave it blank to keep using OAuth.

Both keys are gitignored and never committed. Without a key, the relevant step
is skipped with a warning.

## Repository layout

```
.
├── setup.sh           # Linux bootstrap (apt, nvm, rust, droid, rtk, ...)
├── setup-arch.sh      # Arch Linux bootstrap (pacman + paru/AUR, same toolchain)
├── brew-setup.sh      # macOS bootstrap (Homebrew formulae + casks)
├── lib/
│   └── shared.sh      # sourced by both bootstrap scripts: opencode permission
│                       #   + Baseten BYOK Factory custom-models config
├── config/
│   └── opencode/
│       └── AGENTS.md  # global opencode instructions symlinked to
│                       #   ~/.config/opencode/AGENTS.md
├── tmux.conf          # tmux config symlinked to ~/.tmux.conf
├── bin/
│   ├── droid-export   # export a Factory "droid" session to JSONL / markdown
│   ├── devpod-bundle  # pack/restore SSH + opencode/factory/cursor/grok CLI
│   │                   #   auth+settings for croc Mac <-> dev pod
│   └── droid-to-opencode  -> droid-export   (compat symlink)
├── devpod-bundle      -> bin/devpod-bundle  (run from repo root on any host)
├── skills/            # Factory skill definitions (SKILL.md per skill)
├── baseten_aliases    # kubectl / shell aliases for the baseten monorepo
├── .env.example       # template for BASETEN_API_KEY
└── README.md
```

## What gets installed

### Both platforms (via `lib/shared.sh`)

- **opencode** - installed FIRST among the coding harnesses (official curl
  installer; npm fallback on Linux), with `permission: allow` merged into
  `~/.config/opencode/opencode.json`
- **global opencode instructions** - `config/opencode/AGENTS.md` symlinked to
  `~/.config/opencode/AGENTS.md` (no `/tmp`, lowercase names, worktrees above
  the repo, Docker host networking)
- **droid** (Factory CLI; official curl installer, npm fallback on Linux)
- **Factory custom models** - Baseten BYOK entries written to
  `~/.factory/settings.json` (requires `BASETEN_API_KEY`)
- **FACTORY_API_KEY** - persisted to shell rc files so the `droid` CLI reads it
  from the environment (alternative to OAuth; requires `FACTORY_API_KEY`)
- **CURSOR_API_KEY** - `~/.cursor/env` (mode 600, not in this repo) sourced by
  shell rc files; legacy (the current `cursor-agent` binary does not read it).
  Real cursor auth is file-based via `AGENT_CLI_CREDENTIAL_STORE=file`
  (`~/.cursor/auth.json` on macOS, `~/.config/cursor/auth.json` on Linux),
  carried to dev pods by `devpod-bundle`
- tmux config symlinked to `~/.tmux.conf`
- **~/venv** (via `uv`) with **truss** (Baseten model authoring / deploy-loop)
  and **magic-wormhole** (file transfer); `wormhole` symlinked to `~/.local/bin`
- **croc** (file transfer) - brew formula on macOS,
  GitHub release binary into `~/.local/bin` on Linux

### Linux (`setup.sh`)

- **btop**, tree, build-essential, libclang-dev (best-effort via apt)
- **tmux** (distro package)
- **nvm** + Node.js 26
- **gh** (GitHub CLI, via webi)
- **uv** (Python package manager)
- **Rust** / Cargo (+ `LIBCLANG_PATH` for bindgen)
- **rtk** (Rust Token Killer - LLM token proxy), with hooks for opencode + Cursor
- **paseo** (`@getpaseo/cli@beta`)
- git identity (name + email) configured globally
- `bin/droid-export` and `bin/devpod-bundle` symlinked into `~/.local/bin`

### Arch Linux (`setup-arch.sh`)

Same toolchain as `setup.sh`, with system packages from pacman / AUR instead of
apt:

- **base-devel**, git, **btop**, clang, tree, libevent, ncurses, bison,
  **tmux**, **gh** (as `github-cli`), **croc**, **uv** (best-effort via pacman)
- **paru** (AUR helper, built from the AUR if missing)
- **rtk** (via AUR `rtk-bin`, falling back to the official curl installer)
- everything else (nvm + Node.js 26, pnpm, droid, opencode, paseo, Rust/Cargo,
  Cursor CLI, skills, Baseten CLI, truss venv) installs exactly as in `setup.sh`

### macOS (`brew-setup.sh`)

- Homebrew formulae: `baseten croc gh node mole rtk tmux uv`
- Homebrew casks: `brave-browser@beta grok-build ghostty font-jetbrains-mono-nerd-font`
- `~/.baseten_aliases` created if missing; the managed `ksh` shell helper is
  (re)written and a copy kept in the repo for version control
- **opencode** and **droid** (npm), **cursor-cli** (official curl installer),
  **paseo** (npm)
## tmux config (`tmux.conf`)

Tuned for running TUI agents (Droid, Claude Code, opencode) inside tmux,
including over SSH to remote pods. Symlinked to `~/.tmux.conf` by both setup
scripts. Highlights:

- **mouse on** - wheel events pass through to mouse-tracking TUIs
- **extended-keys** with CSI-u (tmux 3.3+ guarded, so 3.2a doesn't error)
- **256-color + RGB** for `xterm-256color` (Ghostty)
- **escape-time 0** - responsive modal editors
- **focus-events on** - editors/watchers get focus/blur
- **history-limit 100000** - long agent transcripts reachable in copy mode
- **renumber-windows on** - compact window numbers
- **set-clipboard on** - OSC 52 clipboard passthrough to the local machine over SSH

## droid-export (`bin/droid-export`)

Export a Factory "droid" session transcript to a portable, harness-agnostic
format. It only **reads** the droid session JSONL and writes the export - it
performs no writes to opencode (or any other harness's session store), so the
output can be ingested by any downstream agent by simply reading the file.

A droid session lives at
`~/.factory/sessions/<encoded-cwd>/<session-id>.jsonl`.

```bash
droid-export last                       # JSONL to stdout
droid-export <session-id> -o out.jsonl  # JSONL to file
droid-export <id> --format md           # markdown to stdout
droid-export <id> --format md -o out.md # markdown to file
droid-export --list                     # list droid sessions
```

### JSONL schema

One JSON object per line. The first line is a `meta` record; the rest are
`message` or `todos` records.

```jsonl
{"type":"meta","exporter":"droid-export","version":2,"droidSessionId":"...","cwd":"...","title":"...","exportedAt":"..."}
{"type":"message","role":"user","id":"...","timestamp":"...","parent":null,"blocks":[{"type":"text","text":"..."}]}
{"type":"message","role":"assistant","id":"...","timestamp":"...","parent":"...","blocks":[{"type":"reasoning","text":"..."},{"type":"tool_use","id":"...","name":"Execute","input":{...}},{"type":"tool_result","toolUseId":"...","isError":false,"content":"..."}]}
{"type":"todos","timestamp":"...","todos":[{"label":"...","status":"completed"}]}
```

Block types: `text`, `reasoning`, `tool_use` (with original droid tool name +
input), `tool_result`. System-reminder noise blocks are dropped.

`bin/droid-to-opencode` is a symlink to `droid-export` kept for compatibility.

## devpod-bundle (`bin/devpod-bundle`)

Pack the auth + settings for SSH, opencode, Factory droid, Cursor CLI,
grok CLI, and truss (Baseten) into one tar.gz, croc it to a dev pod, and
restore it there - so you only stay logged in on one machine (your Mac).

Paths in the archive are relative to `$HOME`, so restore works on any pod
regardless of username.

**Cursor CLI** auth is file-based: set `AGENT_CLI_CREDENTIAL_STORE=file` so
`cursor-agent` writes `~/.cursor/auth.json` on macOS (and reads
`~/.config/cursor/auth.json` on Linux) instead of the macOS Keychain. That file
IS bundled; on restore it is copied to `~/.config/cursor/auth.json` on Linux.
`~/.cursor/env` (`CURSOR_API_KEY`) is also bundled and sourced by shell rc, but
it is legacy — the current `cursor-agent` binary does not read `CURSOR_API_KEY`.

**Factory droid** auth is file-based too: set `FACTORY_DISABLE_KEYRING=1` so
droid writes the portable `~/.factory/auth.v2.file` + `auth.v2.key` pair instead
of the macOS login keychain (`auth.v2.loginkeychain`, which is NOT portable to
Linux). The `auth.v2.file`/`auth.v2.key` pair IS bundled. The factory mTLS cert
(`~/.factory/cache/certs/factory-cli-certs.pem`) is bundled; re-run
`factory login` on the pod if it has expired. Truss (Baseten) credentials
(`~/.trussrc`) are bundled too; re-run `truss login` on the pod if a remote
needs re-auth.

> **One-time migration on the Mac** (to get out of the keychain): in a new shell
> (after setup has exported the env vars) re-login so the portable files are
> written:
> ```bash
> AGENT_CLI_CREDENTIAL_STORE=file agent auth login   # writes ~/.cursor/auth.json
> FACTORY_DISABLE_KEYRING=1 droid login              # writes ~/.factory/auth.v2.file + auth.v2.key
> ```
> After that, `devpod-bundle --list` should show both files as bundled (not
> "missing").

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

- The only coding harnesses installed are **opencode** (installed first),
  **droid** (Factory CLI), **cursor-cli**, and **grok-build** (macOS only).
  Official curl installers are preferred over package managers; grok-build has
  no curl installer, so it stays a Homebrew cask.
- rtk has no native Droid/Factory integration; it is wired for opencode (plugin)
  and Cursor (preToolUse hook) only.
