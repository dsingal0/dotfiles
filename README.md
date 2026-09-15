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
│   └── devpod-bundle  # pack/restore SSH + omp/factory/truss
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
  setup — no custom agents or plugins. `configure_omp` writes
  `~/.omp/agent/models.yml` with the requested Baseten fallback models plus an
  optional latest-DeepSeek OpenRouter route, and `~/.omp/agent/config.yml` with
  one ordered fallback ladder shared by all model roles. The repo's global rules
  are symlinked to `~/.omp/agent/AGENTS.md`.
- **droid** (Factory CLI) via npm, with Baseten BYOK custom models written to
  `~/.factory/settings.json` (requires `BASETEN_API_KEY`).

### omp model routing

`configure_omp` uses the same route for every role, preserving the requested
order:

1. GitHub Copilot `github-copilot/gemini-3.8-flash` (primary; `:high` for
   `slow` and `plan`).
2. Grok Build/SuperGrok `xai-oauth/grok-4.6`.
3. Cursor `cursor/grok-4.6` (exactly Grok 4.6; no other Cursor model).
4. Baseten `deepseek-ai/DeepSeek-V4.1-Flash`.
5. Baseten `zai-org/GLM-5.3-Flash`.
6. Baseten `zai-org/GLM-5.3`.
7. Baseten `deepseek-ai/DeepSeek-V4-Flash-0731`.
8. Baseten `deepseek-ai/DeepSeek-V4-Pro-0813`.
9. OpenAI Codex `openai-codex/gpt-5.6-luna`.
10. OpenRouter `openrouter/~deepseek/deepseek-flash-latest`.

- `cursor/grok-4.6` is an exact selector. The Cursor wildcard form,
  `cursor/*`, would preserve the current model ID and could select other Cursor
  models; it is intentionally not used.
- `xai-oauth/grok-4.6` is the Grok Build/SuperGrok subscription route and is
  deliberately ahead of Cursor. Both subscription providers have usage
  tracking; `usageReservePct: 1` switches at 1% remaining instead of
  intentionally spending into on-demand usage.
- OMP has no literal dollar-cap setting, so disable on-demand spending in the
  Cursor and Grok account settings to guarantee a hard `$40` ceiling.
- `retry.modelFallback` must remain enabled for this ladder. Entries are
  skipped when their provider has no credentials. Log in with `/login
  github-copilot`, `/login cursor`, `/login xai-oauth`, and `/login
  openai-codex` to enable the subscription-backed routes.
- `usageAwareFallback` switches on provider-reported quota before a hard
  rate-limit response. Unknown usage fails open, so account-level on-demand
  disablement is required for a strict no-overage guarantee.
- `OPENROUTER_API_KEY` is optional. When set, only
  `~deepseek/deepseek-flash-latest` is added; no OpenRouter free models are
  configured.

- **FACTORY_API_KEY** and **FACTORY_DISABLE_KEYRING=1** persisted to shell rc
  files so droid stores auth in the portable `~/.factory/auth.v2.file` +
  `auth.v2.key` pair instead of the macOS login keychain.
- **runlayer MCP** configured in omp and droid.
- **git identity** (name + email) configured globally.
- **rtk** (Rust Token Killer), initialized with its native OMP extension
  (`--agent omp`). It compresses eligible shell command output; source files
  and structured data remain lossless.
- **Caveman** is not inserted as an automatic proxy. Its compression is useful
  for noisy prose/logs, but a proxy would sit in front of every provider route
  and can alter context semantics. If evaluated, use its A/B/trial workflow
  first and keep it off the primary coding path unless the result is
  demonstrably safe.
- **~/venv** (via `uv`) with **truss** (Baseten model authoring / deploy-loop).
- Personal skills from the repo's `skills/` directory, symlinked into OMP and
  Factory droid (`~/.omp/agent/skills/` and `~/.factory/skills/`). The
  `sglang-development` skill is included for canonical SGLang patch tracking.
  Design skills (`frontend-design`) are skipped on Linux dev pods and installed
  only by `brew-setup.sh`. Third-party packs (mattpocock, expo, emilkowalski on
  macOS) are installed via the `skills` CLI into `~/.agents/skills/`
  (`universal`), which omp reads natively.

### SGLang patch workflow

The canonical `sglang-development` skill is vendored at
`skills/sglang-development/SKILL.md` and is linked into every configured harness
by `install_shared_skills`. It governs the Baseten SGLang patch stack:

```sh
make init_sglang
make commit_sglang FEATURE=name DESCRIPTION=/path/description.txt
make review_sglang_patch 12              # or 12..14
make replay_sglang VERSION=vX.Y.Z
make export_sglang
```

Use `SGLANG_SOURCE_DIR=/path/to/sglang` to select another checkout; the default
is `./sglang`. For SGLang changes, agents must read and follow this skill before
editing, keep patches numerically ordered and self-contained, and export patches
separately from committing the enclosing Baseten repository.

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
- Homebrew casks: `brave-browser@beta ghostty font-jetbrains-mono-nerd-font`
- **droid** (npm), plus OMP's native provider integrations
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

Pack the auth + settings for SSH, omp, Factory droid, and truss (Baseten) into
one tar.gz, croc it to a dev pod, and restore it there - so you only stay
logged in on one machine (your Mac).

Paths in the archive are relative to `$HOME`, so restore works on any pod
regardless of username.

**omp** config travels via `~/.omp/agent/models.yml` (Baseten key inline),
`config.yml` (role-specific models + fallback chains), and `mcp.json`.
Every logged-in OMP provider is exported from `agent.db`'s
`auth_credentials` table to `.omp/agent/omp-auth-credentials.json` and merged
back into the pod's `agent.db` during restore. OMP's `agent.db` itself is not
bundled because it also contains machine-local history, caches, and usage data.

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
devpod-bundle -o ~/devpod-bundle-custom.tar.gz  # custom output path
croc send ~/devpod-bundle-*.tar.gz

# On the dev pod (after `git pull` of this repo at ~/dotfiles):
~/dotfiles/devpod-bundle --restore ~/devpod-bundle-*.tar.gz
~/dotfiles/devpod-bundle --restore ~/devpod-bundle-*.tar.gz --dry-run  # list only
# or, without the script: cd ~ && tar -xzf devpod-bundle-*.tar.gz
```

## Notes

- The only coding harnesses installed are **omp** and **droid** (Factory CLI).
- Herdr bash completions are regenerated on Linux if `herdr` is present
  (Herdr itself is installed out-of-band).
