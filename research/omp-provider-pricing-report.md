# omp Provider Pricing Report & $100/Month Budget Strategy

**Date:** 2026-09-14 · **Goal:** every provider the `omp` coding agent supports — subscription tiers, PAYG token pricing — and how to get maximum value from a **$100/month** coding budget.

Companion research files (all in `research/`):
- `first-party-subscription-pricing.md` — Anthropic, OpenAI, Google, xAI, Mistral: tiers + API rates
- `coding-plan-provider-pricing.md` — Kimi, Z.ai/Zhipu, Alibaba, MiniMax, Copilot, Cursor, Cline, iFlow, DeepSeek, Chutes
- `aggregator-gpu-cloud-pricing.md` — OpenRouter, Vercel, NanoGPT, HF + Groq, Cerebras, Baseten, Together, Fireworks, DeepInfra, Novita, SiliconFlow, Nebius, Crusoe, Chutes, etc.
- `omniroute-analysis.md` — OmniRoute gateway / Cheaper Inference as budget multipliers

PAYG prices below are from the models.dev catalog (the same source omp merges for its own cost estimates), cross-checked against the research files' official-page citations. $/Mtok = USD per million tokens (in / out).

---

## 1. omp provider inventory

1. **First-party labs (subscription OAuth or API key):** anthropic, openai, openai-codex, google, google-vertex, xai, xai-oauth, mistral, deepseek, moonshot/kimi, zai, minimax, alibaba/qwen, github-copilot, cursor.


2. **Coding-plan providers (quota-based, $0/token):** zai-coding-plan, zhipuai-coding-plan, kimi-for-coding, minimax-coding-plan, alibaba-coding-plan, alibaba-token-plan, cline-pass, opencode-zen, kilo, opencode-go, umans-ai-coding-plan.
3. **Aggregators & GPU clouds (PAYG):** openrouter, baseten, groq, cerebras, together, fireworks, deepinfra, novita, siliconflow, huggingface, ollama-cloud, nano-gpt, venice, chutes, nebius, crusoe, coreweave, vercel-ai-gateway, cloudflare-ai-gateway, litellm, requesty, tinfoil, modal, and ~30 more hosted providers.
4. **Local:** ollama, llama.cpp, lm-studio, vllm (free compute, your hardware) — plus **custom providers** via `~/.omp/agent/models.yml` (any OpenAI-compatible endpoint, e.g. OmniRoute or Cheaper Inference).

`omp models` lists 550+ models across configured providers; the full models.dev catalog behind omp covers 7,300+ priced models from 213 providers.

## 2. Implemented routing in this repository

The generated `omp` configuration in `lib/shared.sh` uses GitHub Copilot as
the primary provider, preserving prepaid quota before using fallback routes:

- Every role starts with Copilot Gemini 3.8 Flash; `slow` and `plan` select
  its high-thinking variant.
- One shared fallback ladder tries Cursor Grok 4.6, Grok Build/SuperGrok Grok
  4.6, Baseten DeepSeek V4.1 Flash, Baseten GLM-5.3 Flash, Baseten GLM-5.3,
  Baseten DeepSeek V4 Flash 0731, Baseten DeepSeek V4 Pro 0813, Codex
  GPT-5.6 Luna, then `openrouter/~deepseek/deepseek-flash-latest`.
- Cursor and Grok routes use provider-reported subscription usage with a 1%
  reserve. OMP has no literal dollar cap; account-level on-demand disablement
  is required for a strict no-overage ceiling. Unknown usage fails open.

This is the operational setup, not a claim that Copilot is the cheapest API.
The pricing strategies below remain alternatives for choosing subscriptions
and PAYG providers.

## 3. PAYG flagship price board ($/Mtok in / out / cache-read)

| Tier | Model | Best route | In | Out | Cache read |
|---|---|---|---:|---:|---:|
| **Budget** | GLM-5.3-Flash | Z.ai official | $0.075 | $0.25 | $0.015 |
| **Budget** | DeepSeek Flash (V4.1; serves retired V4-flash aliases) | DeepSeek official | $0.30 peak / $0.15 off-peak | $1.20 peak / $0.60 off-peak | $0.006 / $0.003 |
| **Budget** | Gemini 3.6–3.8 Flash | Google (promo to Dec 31) | $0.75 | $3.75 | $0.075 |
| **Budget** | GPT-5.6-Luna | OpenAI | $0.20 | $1.20 | $0.02 |
| **Budget** | MiniMax M2.7 / M3 | MiniMax | $0.30 | $1.20 | $0.06 |
| **Mid** | Kimi K2.7-Code | Moonshot / DeepInfra | $0.68–0.95 | $3.40–4.00 | $0.16–0.19 |
| **Mid** | GLM-5.2 / GLM-5.3 | Z.ai / DeepInfra / CoreWeave | $0.76–1.40 | $2.42–4.40 | $0.12–0.26 |
| **Mid** | DeepSeek V4-Pro | DeepSeek official | $1.32 | $3.96 | $0.044 (off-peak: half) |
| **Mid** | Grok-Build-0.1 | xAI | $1.00 | $2.00 | — |
| **Mid** | Qwen3.7-Plus | Alibaba | $0.40 | $1.60 | $0.08 |
| **Frontier** | Claude Sonnet 5 | Anthropic | $2.00 | $10.00 | $0.20 |
| **Frontier** | GPT-5.6-Terra | OpenAI | $2.00 | $12.00 | $0.20 |
| **Frontier** | Gemini 3.1-Pro | Google | $2.00 | $12.00 | $0.20 |
| **Frontier** | Grok 4.6 | xAI | $2.00 | $6.00 | $0.50 |
| **Premium** | Claude Opus 5 | Anthropic | $5.00 | $25.00 | $0.50 |
| **Premium** | GPT-5.5 | OpenAI | $5.00 | $30.00 | $0.50 |
| **Premium** | Kimi K3 | Moonshot | $3.00 | $15.00 | $0.30 |
| **Premium** | Claude Fable 5.1 | Anthropic | $10.00 | $50.00 | $0.25 |

**Key metric for agentic coding: cache-read.** A typical agent session sends 2–10M input tokens, 80–95% of which are cache hits (re-sent conversation prefix), plus 50–200K output. Blended cost of a session ≈ `in_cache × cache_read + in_new × input + out × output`. On that mix, DeepSeek-Flash blended ≈ **$0.17/Mtok peak**, GLM-5.3-Flash ≈ **$0.30/Mtok** — the two cheapest competent agentic APIs available. Kimi K3 at the premium end is 10× that; Claude Sonnet 5 ~$2.5/Mtok blended.

## 4. Subscription landscape at a glance

| Plan | $/mo | What you get (API-equivalent value at full use) |
|---|---:|---|
| **ClinePass** | $9.99 | 2–5× API-rate usage across GLM-5.3, Kimi K3/K2.7, MiniMax M3, Qwen Max ≈ $20–50 |
| **NanoGPT sub** | $12 | 60M input tok/week (~260M/mo) on open-weight models ≈ $250–780 |
| **Kimi Moderato** | $19 | Kimi Code shared pool; K2.7-Code-class ≈ $25–35+ |
| **GLM Coding Plan Lite** | $18 ($12.60 annual) | 48–97M tok/wk GLM-5.3 + unlimited nightly GLM-5.3-Flash (campaign) ≈ $115–230 |
| **Ollama Cloud Pro** | $20 | $60 of list-rate usage (3×) |
| **MiniMax Token Plan Plus** | $20–22 | ~4,500 calls/5h on M2.7 ≈ $45+ |
| **GitHub Copilot Pro** | $10 | 1,500 AI credits ($15 metered) + unlimited completions |
| **Alibaba Token Plan Std** | $18 | 10,000 credits/7d, multi-model |
| **GLM Coding Plan Pro** | $80 ($56 annual) | 290–580M tok/wk GLM-5.3 ≈ **$680–1,360** — best published allowance per $ |
| **MiniMax Token Plan Max** | $50–55 | ~15,000 calls/5h on M2.7 ≈ $135+ |
| **Cerebras Code Pro** | $50 | 24M tok/day GLM-4.7 on wafer-scale speed ≈ $660 at full use |
| **GitHub Copilot Max** | $100 | 20,000 credits ($200 metered at 2× face) incl. Claude/GPT/Gemini |
| **Claude Max 5x** | $100 | ~5× Pro Claude Code usage ≈ $100–300 at Sonnet-5 rates |
| **ChatGPT Pro 5x (Codex)** | $100 | 5× Plus Codex; ~50–500 Sol msgs/5h ≈ $250–1,000 |
| **Google AI Ultra 5x** | $99.99 | ~5× Pro quota, Antigravity CLI ≈ $100–300 |
| **Kimi Allegro** | $99 | K2.7-Code/K3 via omp, 5h+weekly caps |
| **Alibaba Token Plan Pro** | $68 | 40,000 credits/7d, 6–8 concurrent agents |
| **Cursor Pro+** | $60 | $70 of API-agent usage |

(Derived-value figures are [ESTIMATE]/[INFERENCE] — see research files for per-plan citations and caveats.)

## 5. $100/month strategies (ranked)

### Strategy A — "Max value, open-weight core" ≈ $88–100/mo
| Spend | Item | Role |
|---|---|---|
| $56 (annual eff.) | GLM Coding Plan Pro | Daily driver: GLM-5.3 for everything; unlimited GLM-5.3-Flash 23:00–09:00 campaign for overnight batch runs |
| $9.99 | ClinePass | Second vendor diversity (Kimi K2.7/K3, MiniMax M3, Qwen) when GLM quota gates |
| $15–34 | PAYG (DeepSeek + Z.ai API) | DeepSeek-Flash off-peak for bulk/grunt ($0.075/$0.30 off-peak); frontier top-ups |
| $0 | OmniRoute sidecar | Free-tier floor for smol/prewalk work + fallback chains + quota-aware routing |

Expected yield: GLM Pro alone publishes 290–580M GLM-5.3 tokens/week (~1.2–2.5B/mo) — at list prices that's **$680–1,360/mo equivalent**, the highest published allowance per dollar anywhere. Add DeepSeek off-peak and free tiers and a heavy coder can move 1.5–3B tokens/month within budget.

### Strategy B — "One subscription, frontier included" = $100/mo
| Spend | Item | Role |
|---|---|---|
| $100 | GitHub Copilot Max | 20,000 AI credits ($200 metered face value) across Claude Sonnet 5, GPT-5.3-Codex, Gemini Flash, plus unlimited completions and code review |

Best if you want first-party frontier models (Claude/GPT/Gemini) metered in one plan and also use VS Code/IDE features. Weakness: credits run out — 20,000 credits ≈ 25–35M Sonnet-class tokens; heavy agent use burns that in 1–2 weeks.

### Strategy C — "Claude Code maximalist" = $100/mo
Claude Max 5x: ~5× Pro Claude Code usage, best-in-class model, no metering anxiety (5h/weekly windows instead). Worth it **only** if Claude Code with Sonnet 5/Opus is your primary workflow and you value frontier quality over token volume. Equivalent API value ~$100–300/mo — far fewer tokens than Strategy A, but highest per-task quality ceiling.

### Strategy D — "Pure PAYG, zero subscriptions" = $100/mo
DeepSeek-Flash + GLM-5.3-Flash + Gemini 3.8-Flash promo + GPT-5.6-Luna as workhorses, Claude Sonnet 5 / GPT-5.6-Terra reserve for hard tasks, routed via OmniRoute for fallback + Cheaper Inference for the frontier slice (GPT-5.6-Terra at $0.80/$4.80 = 60% off).
At blended rates: ~$70 of workhorse spend ≈ **300–500M tokens/mo**; $30 of frontier reserve ≈ 10–15M Sonnet/Terra tokens for the hardest 5% of tasks. Most flexible, no quota windows, but requires watching spend (omp's cost telemetry + OmniRoute per-key USD caps help).

### Recommendation
- **Token-volume maximizer / open-weight comfortable:** Strategy A. The GLM Coding Plan Pro is the single best value in the market right now — and its $56 annual-effective price leaves half the budget for a second plan or PAYG diversity.
- **Frontier-quality first:** Strategy B (Copilot Max) if you want model variety in one subscription; Strategy C (Claude Max 5x) if you're all-in on Claude Code.
- **Whatever you pick, add OmniRoute ($0):** free-tier floor for cheap work, fallback chains so outages don't burn budget, and subscription-quota-first routing. Optionally route a capped frontier slice through Cheaper Inference for 60% off OpenAI list.

## 6. Watch-outs (time-sensitive, as of 2026-09-14)

- **Gemini 3.6–3.8 Flash promo ($0.75/$3.75) ends Dec 31, 2026** — doubles after.
- **GPT-5.6-Sol promo API pricing ends Nov 21, 2026.**
- **DeepSeek off-peak** = all times except Mon–Fri 01:00–04:00 & 06:00–10:00 UTC (half price); schedule batch work accordingly.
- **Z.ai off-peak credits** = 50% outside Mon–Fri 14:00–18:00 SGT; nightly 23:00–09:00 unlimited GLM-5.3-Flash campaign currently running.
- **ChatGPT Pro 20x ($200) new sign-ups paused since Sept 10, 2026.**
- **Qwen free OAuth discontinued April 15, 2026** — Qwen Code now needs Coding/Token Plan or third-party API.
- Grey-market floors (merge-gateway, bothub, xpersona at 20–80% below official) imply unofficial upstreams — ToS/ban/privacy risk; fine for scratch code, avoid for proprietary code. Cerebras Code Pro is rate-limited by daily caps; NanoGPT sub counts cached input against quota (agent workloads burn it fast).
- MiniMax docs/checkout price mismatch ($22 vs $20 etc.) — verify at checkout.

## 7. Method & verification

- PAYG rates: models.dev `api.json` snapshot (213 providers, 7,349 models), 2026-09-14 — the same catalog omp merges for cost estimates. Scratch files: `.omp-modelsdev.json`, `.omp-pricing-extract.json`, `.omp-flagship-prices.json`, `.omp-models-catalog.json`.
- Subscription tiers: live official pricing pages, researched 2026-09-14; [UNVERIFIED] flags preserved in the research files.
- Spot-checks done: GLM-5.3-Flash (0.075/0.25), DeepSeek-V4-Flash (0.15/0.6), Kimi K2.7-Code (0.95/4), Claude Sonnet 5 (2/10), GPT-5.6-Terra (2/12) all match between catalog and official pages. Chutes TEE, Tinfoil, and grey-market reseller rates carry premiums or risks noted above.
