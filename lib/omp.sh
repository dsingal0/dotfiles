# omp.sh - oh-my-pi (omp) install + config shared by every bootstrap script.
#
# Sourced by lib/shared.sh; not executable on its own.

# Install oh-my-pi (@oh-my-pi/pi-coding-agent). The package ships a
# bun-compiled binary, so bun is installed first if missing; npm is the
# fallback installer.
install_omp() {
  echo "Installing oh-my-pi (omp)..."
  if ! command -v bun >/dev/null 2>&1; then
    echo "  bun not found (required by the omp binary); installing via bun.sh..."
    curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1 \
      || echo "WARNING: bun install failed; will try the npm fallback for omp." >&2
    export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
    export PATH="$BUN_INSTALL/bin:$PATH"
  fi
  if command -v bun >/dev/null 2>&1; then
    bun install -g @oh-my-pi/pi-coding-agent \
      || echo "WARNING: omp install failed (continuing)." >&2
  else
    npm install -g @oh-my-pi/pi-coding-agent \
      || echo "WARNING: omp install failed (continuing)." >&2
  fi
}

# Symlink the repo's global omp instructions into ~/.omp/agent/AGENTS.md so
# every project session picks up the same global rules. Idempotent.
# Pass the repo root as $1.
install_global_agents_md() {
  local repo_dir="$1"
  local src="$repo_dir/config/omp/AGENTS.md"
  local dest="$HOME/.omp/agent/AGENTS.md"

  if [[ ! -f "$src" ]]; then
    echo "NOTE: no global AGENTS.md at $src; skipping."
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    mv -f "$dest" "$dest.bak"
    echo "  backed up existing ~/.omp/agent/AGENTS.md -> AGENTS.md.bak"
  fi
  ln -sfn "$src" "$dest"
  echo "Global omp AGENTS.md installed: $dest -> $src"
}

# Ensure runlayer MCP is configured in omp and droid/Factory. Idempotent.
configure_runlayer_mcp() {
  local url="https://baseten.runlayer.com/mcp"
  upsert_mcp_server "$HOME/.omp/agent/mcp.json" "runlayer" "$url"
  upsert_mcp_server "$HOME/.factory/mcp.json" "runlayer" "$url" '{"disabled": false}'
  echo "  runlayer MCP configured (omp + droid)"
}

# Initialize the RTK integration for OMP (native extension, --agent omp).
configure_rtk() {
  if ! command -v rtk >/dev/null 2>&1; then
    echo "WARNING: rtk not found; skipping RTK integration."
    return 0
  fi

  echo "Configuring RTK integration for OMP..."
  RTK_TELEMETRY_DISABLED=1 rtk init -g --agent omp --hook-only --no-patch
  RTK_TELEMETRY_DISABLED=1 rtk init --show
}

# Configure omp (vanilla — no custom agents; omp's built-in task tool and the
# model roles are the whole setup):
#   ~/.omp/agent/models.yml    Baseten fallback models + optional OpenRouter latest
#   ~/.omp/agent/config.yml    one ordered ladder shared by all model roles
# Idempotent: every file is regenerated on each run. Keys are embedded at
# setup time (repo is private) and models.yml is chmod 600. The global
# AGENTS.md symlink is owned by install_global_agents_md, not this function.
configure_omp() {
  if [[ -z "${BASETEN_API_KEY:-}" ]]; then
    echo "WARNING: BASETEN_API_KEY is not set. Skipping omp config."
    echo "         To enable: cp .env.example .env and fill in your key."
    return 0
  fi
  mkdir -p ~/.omp/agent

  # --- models.yml: Baseten fallback models + latest OpenRouter DeepSeek -------
  # Keep every requested Baseten fallback explicit. compat blocks replace rather
  # than merge in omp, so each model spells out its complete wire contract.
  cat > ~/.omp/agent/models.yml <<EOF
# Managed by dotfiles setup (configure_omp in lib/omp.sh) — hand edits are
# overwritten on the next setup run.
providers:
  baseten:
    baseUrl: https://inference.baseten.co/v1
    api: openai-completions
    apiKey: "${BASETEN_API_KEY}"
    authHeader: true
    models:
      - id: deepseek-ai/DeepSeek-V4.1-Flash
        name: DeepSeek V4.1 Flash
        reasoning: false
        input: [text]
        contextWindow: 1048576
        maxTokens: 32768
        compat:
          supportsDeveloperRole: false
          supportsReasoningEffort: false
          maxTokensField: max_tokens
      - id: zai-org/GLM-5.3-Flash
        name: GLM 5.3 Flash
        reasoning: true
        input: [text]
        contextWindow: 200000
        maxTokens: 262144
        thinking: { mode: effort, minLevel: high, maxLevel: max }
        compat:
          supportsDeveloperRole: false
          supportsReasoningEffort: true
          maxTokensField: max_tokens
      - id: zai-org/GLM-5.3
        name: GLM 5.3
        reasoning: true
        input: [text]
        contextWindow: 200000
        maxTokens: 262144
        thinking: { mode: effort, minLevel: high, maxLevel: max }
        compat:
          supportsDeveloperRole: false
          supportsReasoningEffort: true
          maxTokensField: max_tokens
      - id: deepseek-ai/DeepSeek-V4-Flash-0731
        name: DeepSeek V4 Flash 0731
        reasoning: false
        input: [text]
        contextWindow: 200000
        maxTokens: 1048576
        compat:
          supportsDeveloperRole: false
          supportsReasoningEffort: false
          maxTokensField: max_tokens
      - id: deepseek-ai/DeepSeek-V4-Pro-0813
        name: DeepSeek V4 Pro 0813
        reasoning: true
        input: [text]
        contextWindow: 200000
        maxTokens: 262144
        thinking: { mode: effort, minLevel: high, maxLevel: max }
        compat:
          supportsDeveloperRole: false
          supportsReasoningEffort: true
          maxTokensField: max_tokens
  # Local SWE-2 slice on rack 17 (kimi-k3-swe-2-omp, 1xTP8 DSpark batch-4).
  # Served via a persistent port-forward on 127.0.0.1:18090; auth none.
  # Unreachable entries are skipped by the fallback ladder, so this is safe
  # to keep even when the slice is down.
  swe2:
    baseUrl: http://127.0.0.1:18090/v1
    api: openai-completions
    auth: none
    models:
      - id: moonshotai/Kimi-K3
        name: SWE-2 (rack17 omp slice)
        reasoning: true
        input: [text]
        contextWindow: 1048576
        maxTokens: 49152
        thinking: { mode: effort, minLevel: low, maxLevel: max }
        compat:
          supportsDeveloperRole: false
          supportsReasoningEffort: true
          maxTokensField: max_tokens
EOF

  # OpenRouter fallback: use only the rolling latest DeepSeek Flash alias.
  # No OpenRouter free-tier models are configured. The alias is quoted because
  # its model id intentionally begins with "~".
  if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    cat >> ~/.omp/agent/models.yml <<EOF
  openrouter:
    baseUrl: https://openrouter.ai/api/v1
    api: openai-completions
    apiKey: "${OPENROUTER_API_KEY}"
    authHeader: true
    models:
      - id: "~deepseek/deepseek-flash-latest"
        name: DeepSeek Flash Latest (OpenRouter)
        reasoning: true
        input: [text]
        contextWindow: 1048576
        maxTokens: 384000
        thinking: { mode: effort, minLevel: low, maxLevel: max }
        compat:
          maxTokensField: max_tokens
EOF
  else
    echo "NOTE: OPENROUTER_API_KEY is not set. Latest DeepSeek Flash fallback skipped."
  fi
  chmod 600 ~/.omp/agent/models.yml

  # --- config.yml: one ordered ladder for every model role ---------------------
  # Every role uses the local SWE-2 rack-17 slice (one model, one string); the
  # fallback ladder below catches a down/saturated slice and spillover. Grok 4.6
  # is reachable three ways — xAI OAuth, Cursor (id cursor-grok-4.6), and
  # Copilot — all three ride the ladder before Baseten. Codex Luna/Sol/Astra and
  # the OpenRouter DeepSeek alias are the final safety net.

  cat > ~/.omp/agent/config.yml <<EOF
# Managed by dotfiles setup (configure_omp in lib/omp.sh) — hand edits are
# overwritten on the next setup run.
modelRoles:
  # All roles on the local SWE-2 slice (one model, one string — simplest). The
  # fallback ladder below catches a down/saturated slice and spillover.
  default: swe2/moonshotai/Kimi-K3
  smol: swe2/moonshotai/Kimi-K3
  slow: swe2/moonshotai/Kimi-K3
  task: swe2/moonshotai/Kimi-K3
  tiny: swe2/moonshotai/Kimi-K3
  commit: swe2/moonshotai/Kimi-K3
  plan: swe2/moonshotai/Kimi-K3
  advisor: swe2/moonshotai/Kimi-K3

retry:
  enabled: true
  modelFallback: true
  fallbackRevertPolicy: cooldown-expiry
  maxRetries: 10
  # Preflight supported provider usage before each request. At the 1% remaining
  # reserve, switch before included subscription usage is exhausted, avoiding
  # intentional on-demand spill. Unknown usage still fails open per omp policy.
  usageAwareFallback: true
  usageReservePct: 1
  usageReservePolicy: auto
  fallbackChains:
    # Overall model preference order (2026-09-18), free/already-paid-for only:
    #   1. SWE-2 (swe2 — local rack-17 slice; the default role's model)
    #   2. Grok 4.6 on xAI OAuth / Cursor / Copilot (three routes, same model).
    #      NOTE: Cursor's model id is cursor-grok-4.6 (provider prefixes
    #      "cursor-"); a bare "cursor/grok-4.6" id does not exist and is skipped.
    #   3. Antigravity Gemini 3.8 flash (antigravity/gemini-3.8-flash).
    #   4. Muse 1.3 — NOT routed: not on the Baseten mapi (checked /v1/models);
    #      coding-assistant-only, no omp provider. Skipped.
    #   5-9. Baseten mapi: DeepSeek-V4.1-Flash, GLM-5.3, GLM-5.3-Flash,
    #      DeepSeek-V4-Flash-0731, DeepSeek-V4-Pro-0813 (in that order).
    #  10. Cursor Composer 2.5 (id composer-2.5; added per request, before openrouter).
    #  11. OpenRouter rolling DeepSeek Flash alias.
    # Codex models sit at the very end as the safety net, in order:
    # Luna, then Sol, then Astra (openai luna/sol/astra).
    default:
      - xai-oauth/grok-4.6
      - cursor/cursor-grok-4.6
      - github-copilot/grok-4.6
      - antigravity/gemini-3.8-flash
      - baseten/deepseek-ai/DeepSeek-V4.1-Flash
      - baseten/zai-org/GLM-5.3
      - baseten/zai-org/GLM-5.3-Flash
      - baseten/deepseek-ai/DeepSeek-V4-Flash-0731
      - baseten/deepseek-ai/DeepSeek-V4-Pro-0813
      - cursor/composer-2.5
      - openrouter/~deepseek/deepseek-flash-latest
      - openai-codex/gpt-5.6-luna
      - openai-codex/gpt-5.6-sol
      - openai-codex/gpt-6-astra
EOF

  # Vanilla: no custom agents under ~/.omp/agent/agents — omp's built-in
  # task tool spawns subagents on the "task" role, which inherits the
  # default chain above. Remove specialist agents from earlier setup
  # runs so the config stays clean.
  rm -f ~/.omp/agent/agents/{explorer,librarian,fixer,designer,oracle}.md
  rmdir ~/.omp/agent/agents 2>/dev/null || true

  echo "  omp configured (models.yml, config.yml — vanilla, no custom agents)."
  echo "  Global AGENTS.md symlink + skills + runlayer MCP are owned by other functions."
}
