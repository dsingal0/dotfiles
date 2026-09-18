# dotfiles

Personal dotfiles + bootstrap for spinning up a new dev machine, remote dev
pod, or fresh box with the same tools and config.

Three platform scripts share one config layer in `lib/`:

| Script | Platform | Package manager |
|---|---|---|
| `setup.sh` | Linux / dev pods | apt |
| `setup-arch.sh` | Arch Linux | pacman + paru/AUR |
| `brew-setup.sh` | macOS | Homebrew |

All three are idempotent — re-run to install or update. Each installs its
platform toolchain, then calls `bootstrap_common` for the shared config.

## Setup

```bash
git clone https://github.com/dsingal0/dotfiles ~/dotfiles
cd ~/dotfiles
cp .env.example .env        # fill in BASETEN_API_KEY (+ optional FACTORY/OPENROUTER)
./setup.sh                  # or ./setup-arch.sh / ./brew-setup.sh
```

Without `BASETEN_API_KEY`, the model-config steps skip with a warning.

## Layout

```
setup.sh / setup-arch.sh / brew-setup.sh   # thin platform entry points
lib/
  shared.sh      # aggregator — sources all modules below
  bootstrap.sh   # bootstrap_common: the shared post-toolchain sequence
  rc.sh          # rc-file + env helpers (managed blocks, PATH, .env)
  python.sh      # shared python helpers (mcp upsert, gh release tag)
  omp.sh         # omp install + config + runlayer MCP + RTK init
  factory.sh     # Factory droid BYOK models + auth
  skills.sh      # agent skill install + cleanup
  tools.sh       # tool installers (droid, baseten, croc, venv, node, rust, uv)
bin/devpod-bundle    # pack/restore auth+settings for Mac <-> dev pod sync
clone_runtimes.sh    # parallel-clone the Baseten/vLLM/TRT-LLM repos
config/omp/AGENTS.md # global omp rules, symlinked into ~/.omp/agent
skills/              # personal skills, symlinked into each harness
baseten_aliases      # kubectl / shell aliases for the baseten monorepo
tmux.conf            # -> ~/.tmux.conf
ghostty.conf         # -> ~/.config/ghostty/config (macOS)
.env.example         # template for API keys
```

## What gets installed

- **omp** (`@oh-my-pi/pi-coding-agent`), the coding harness. `configure_omp`
  writes `~/.omp/agent/models.yml` (SWE-2 slice + Baseten + OpenRouter
  providers) and `~/.omp/agent/config.yml` (one ordered fallback ladder shared
  by all roles). The repo's global rules are symlinked to
  `~/.omp/agent/AGENTS.md`.
- **droid** (Factory CLI) via npm, with Baseten BYOK custom models in
  `~/.factory/settings.json` (needs `BASETEN_API_KEY`).
- **runlayer MCP** in omp + droid, **RTK** (token-saving CLI proxy) initialized
  for omp, **git identity**, `~/venv` (uv) with **truss**, and personal +
  third-party **skills** symlinked into each harness.

### omp model routing

Every role (`default`, `task`, `slow`, `plan`, `smol`, `tiny`, `commit`,
`advisor`) uses the local SWE-2 rack-17 slice (`swe2/moonshotai/Kimi-K3`). When
it's unreachable or saturated, `retry.modelFallback` walks this ladder:

1. Grok 4.6 — `xai-oauth` → `cursor/cursor-grok-4.6` → `github-copilot` (3 routes)
2. Antigravity Gemini 3.8 flash — `antigravity/gemini-3.8-flash`
3. Baseten mapi — `DeepSeek-V4.1-Flash` → `GLM-5.3` → `GLM-5.3-Flash` → `DeepSeek-V4-Flash-0731` → `DeepSeek-V4-Pro-0813`
4. Cursor Composer 2.5 — `cursor/composer-2.5`
5. OpenRouter — `~deepseek/deepseek-flash-latest`
6. OpenAI Codex — `gpt-5.6-luna` → `gpt-5.6-sol` → `gpt-6-astra` (safety net)

Notes:

- `usageReservePct: 1` switches at 1% remaining quota instead of spending into
  on-demand. Unknown usage fails open, so also disable on-demand spending in
  the Cursor / Grok / Copilot account settings for a hard ceiling.
- Fallback entries are skipped when their provider has no credentials. Enable
  routes with `/login github-copilot`, `/login cursor`, `/login xai-oauth`,
  `/login antigravity`, `/login openai-codex`.
- `OPENROUTER_API_KEY` is optional; only the rolling DeepSeek Flash alias is added.

## tmux.conf

Tuned for TUI agents (omp, droid) in tmux, including over SSH: mouse on,
extended-keys (tmux 3.3+ guarded), 256-color + RGB, escape-time 0,
focus-events, history-limit 100000, OSC 52 clipboard passthrough.

## devpod-bundle (`bin/devpod-bundle`)

Pack SSH + omp + Factory droid + truss auth/settings into one tar.gz, croc it
to a dev pod, restore there — stay logged in on one machine (your Mac). Paths
are `$HOME`-relative so restore works on any pod. See `devpod-bundle --help`
or the file header for the full doc.

```bash
devpod-bundle                              # write ~/devpod-bundle-<stamp>.tar.gz
devpod-bundle --list                       # dry run, write nothing
~/dotfiles/devpod-bundle --restore <file>  # on the pod
```
