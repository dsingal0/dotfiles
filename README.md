# dotfiles

Personal dotfiles and bootstrap scripts for spinning up a new dev machine,
remote dev pod, or any fresh box with the same tools and config as this one.

Two platform bootstrap scripts share a common config layer in `lib/shared.sh`:

- **`setup.sh`** - Linux / apt-based dev pods.
- **`brew-setup.sh`** - macOS (Homebrew).

Both are idempotent: re-run them to install or update tools on an existing
machine. Run the one for your platform.

## Setup

```bash
git clone https://github.com/dsingal0/dotfiles ~/dotfiles
cd ~/dotfiles

# Linux (apt-based):
./setup.sh

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
├── setup.sh           # Linux bootstrap (apt, nvm, rust, factory cli, rtk, ...)
├── brew-setup.sh      # macOS bootstrap (Homebrew formulae + casks)
├── lib/
│   └── shared.sh      # sourced by both bootstrap scripts: opencode permission
│                       #   + Baseten BYOK Factory custom-models config
├── tmux.conf          # tmux config symlinked to ~/.tmux.conf
├── bin/
│   ├── droid-export   # export a Factory "droid" session to JSONL / markdown
│   ├── devpod-bundle  # pack/restore SSH + opencode/factory/cursor/grok CLI
│   │                   #   auth+settings for wormhole Mac <-> dev pod
│   └── droid-to-opencode  -> droid-export   (compat symlink)
├── devpod-bundle      -> bin/devpod-bundle  (run from repo root on any host)
├── skills/            # Factory skill definitions (SKILL.md per skill)
├── baseten_aliases    # kubectl / shell aliases for the baseten monorepo
├── .env.example       # template for BASETEN_API_KEY
└── README.md
```

## What gets installed

### Both platforms (via `lib/shared.sh`)

- **opencode** (`opencode-ai` via npm) with `permission: allow` merged into
  `~/.config/opencode/opencode.json`
- **droid** (Factory CLI, via npm)
- **Factory custom models** - Baseten BYOK entries written to
  `~/.factory/settings.json` (requires `BASETEN_API_KEY`)
- **FACTORY_API_KEY** - persisted to shell rc files so the `droid` CLI reads it
  from the environment (alternative to OAuth; requires `FACTORY_API_KEY`)
- **CURSOR_API_KEY** - `~/.cursor/env` (mode 600, not in this repo) sourced by
  shell rc files via a managed block so the Cursor CLI `agent` uses API-key
  auth; the key file is carried to dev pods by `devpod-bundle`
- tmux config symlinked to `~/.tmux.conf`
- **~/venv** (via `uv`) with **truss** (Baseten model authoring / deploy-loop)
  and **magic-wormhole** (file transfer, replaces croc); `wormhole` symlinked
  to `~/.local/bin`

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

### macOS (`brew-setup.sh`)

- Homebrew formulae: `baseten gh node mole rtk tmux uv`
- Homebrew casks: `brave-browser@beta droid iterm2`
- `~/.baseten_aliases` created if missing; the managed `ksh` shell helper is
  (re)written and a copy kept in the repo for version control
- **opencode**, **droid**, **paseo** (npm)

## tmux config (`tmux.conf`)

Tuned for running TUI agents (Droid, Claude Code, opencode) inside tmux,
including over SSH to remote pods. Symlinked to `~/.tmux.conf` by both setup
scripts. Highlights:

- **mouse on** - wheel events pass through to mouse-tracking TUIs
- **extended-keys** with CSI-u (tmux 3.3+ guarded, so 3.2a doesn't error)
- **256-color + RGB** for `xterm-256color` (iTerm2)
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

Pack the auth + settings for SSH, opencode, Factory droid, Cursor CLI, and
grok CLI into one tar.gz, wormhole it to a dev pod, and restore it there -
so you only stay logged in on one machine (your Mac).

Paths in the archive are relative to `$HOME`, so restore works on any pod
regardless of username. Cursor CLI auth uses an API key (`CURSOR_API_KEY`)
stored in `~/.cursor/env` (mode 600, not in this repo), which IS bundled; shell
rc files source it via a managed block added by `setup.sh` / `brew-setup.sh`
(`configure_cursor` in `lib/shared.sh`). The factory mTLS cert
(`~/.factory/cache/certs/factory-cli-certs.pem`) is bundled; re-run
`factory login` on the pod if it has expired.

```bash
# On the Mac (the machine you stay logged in on):
devpod-bundle                          # writes ~/devpod-bundle-<stamp>.tar.gz
devpod-bundle --list                   # dry run, write nothing
devpod-bundle -o /tmp/x.tgz            # custom output path
wormhole send ~/devpod-bundle-*.tar.gz

# On the dev pod (after `git pull` of this repo at ~/dotfiles):
~/dotfiles/devpod-bundle --restore ~/devpod-bundle-*.tar.gz
~/dotfiles/devpod-bundle --restore ~/devpod-bundle-*.tar.gz --dry-run  # list only
# or, without the script: cd ~ && tar -xzf devpod-bundle-*.tar.gz
```

## Notes

- Cursor CLI and Claude CLI installs in `setup.sh` are currently commented out;
  only opencode and droid harnesses are active.
- rtk has no native Droid/Factory integration; it is wired for opencode (plugin)
  and Cursor (preToolUse hook) only.
