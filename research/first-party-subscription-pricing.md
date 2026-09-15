# First-party AI provider pricing: subscriptions + pay-as-you-go API (Sept 2026)

Compiled 2026-09-14 for a $100/month coding-budget optimization report on the `omp` coding agent. `omp` addresses models as `provider/model-id` (e.g. `anthropic/claude-sonnet-5`, `openai/gpt-5.6-terra`, `google/gemini-3.1-pro`, `xai/grok-4.6`, `mistral/mistral-large-3`), and also supports **subscription-backed OAuth login** for Anthropic and OpenAI Codex — which is why consumer/subscription tiers below matter for coding budgets, not just raw API keys.

All prices USD, per month unless noted. Everything verified against live pages during Sept 2026 unless tagged **[UNVERIFIED]**.

---

## 1. Anthropic

### 1a. Subscription tiers (claude.ai / Claude Code)

| Tier | Price/mo | Model access | Usage limits |
|---|---|---|---|
| Free | $0 | Limited Claude access; no Claude Code | Small usage cap, no Claude Code access |
| Pro | $20 (or $17/mo-equivalent billed annually at $200/yr) | Full Claude model lineup + Claude Code | Claude Code included; usage shared across web/desktop/mobile/Claude Code; ~5-hour session limits + separate weekly limit |
| Max 5x | $100/mo (monthly billing only) | All models, incl. top Claude models + Claude Code, Projects, deeper Research | ~5x Pro usage per 5-hour session; separate weekly limits |
| Max 20x | $200/mo (monthly billing only) | All models + Claude Code, highest priority access | ~20x Pro usage per 5-hour session; separate weekly limits |

- Paid plans can also buy **usage credits** (pay-as-you-go, drawn after plan allowance hits session/weekly limits).
- Claude Code usage draws from the same allowance as chat across web/desktop/mobile.
- Enterprise-only: Team / Enterprise plans (SSO, compliance API, HIPAA) — not covered here.
- Sources: https://claude.com/pricing ; https://support.claude.com/en/articles/11145838 ; https://support.claude.com/en/articles/11049741 ; https://support.claude.com/en/articles/11647753 ; https://support.claude.com/en/articles/9797557

### 1b. API pricing ($/Mtok in / out)

| Model family | Input | Output | Cache read | Cache write (5-min / 1-hr) | Notes |
|---|---|---|---|---|---|
| Claude Fable 5.1 | $10.00 | $50.00 | $0.25 (0.025x base) | 1.25x / 2x base input | Flagship |
| Claude Mythos 5.1 | $10.00 | $50.00 | $0.25 | 1.25x / 2x | Limited availability |
| Claude Opus 5, 4.8, 4.7, 4.6, 4.5 | $5.00 | $25.00 | $0.50 | 1.25x / 2x | Fast mode on Opus 5/4.8: $10/$50 |
| Claude Sonnet 5 | $2.00 | $10.00 | $0.20 | 1.25x / 2x | Intro price made permanent Sept 2026 |
| Claude Sonnet 4.6, 4.5 | $3.00 | $15.00 | $0.30 | 1.25x / 2x | |
| Claude Haiku 4.5 | $1.00 | $5.00 | $0.10 | 1.25x / 2x | |
| Opus 4.1 / 4 (retired) | $15.00 | $75.00 | — | — | Legacy reference |

- Prompt Caching batch: **50% discount**; US data residency (`inference_geo: "us"`) multiplies cost 1.1x; full 1M-token context at standard pricing for Sonnet 4.6+.
- Source: https://platform.claude.com/docs/en/about-claude/pricing

### 1c. API-equivalent value estimate

| Tier | Price/mo | Estimated API-equivalent token value [ESTIMATE] |
|---|---|---|
| Pro ($20) | ~1,000-3,000 Sonnet-5-equivalent $/Mtok of usage | ~$20-60/mo at Sonnet 5 rates if fully consumed; heavily discounted vs raw API |
| Max 5x ($100) | ~5x Pro usage | ~$100-300/mo at Sonnet 5 rates; ~$50-150/mo at Opus 5 rates (if mostly Opus work) |
| Max 20x ($200) | ~20x Pro usage | ~$400-1,200/mo at Sonnet 5 rates [ESTIMATE] |

Estimates are indicative only — Anthropic does not publish token-denominated subscription allowances. Claude Code usage on Max plans is generally the best $/value among first-party subscriptions when heavy Claude Code use is the goal.

---

## 2. OpenAI

### 2a. Subscription tiers (ChatGPT + Codex)

| Tier | Price/mo | Model access | Usage limits |
|---|---|---|---|
| Free | $0 | Limited models; Codex free tier for quick tasks | Very limited |
| Go | $8 | Codex on web/CLI/IDE/iOS for lightweight tasks | Light usage |
| Plus | $20 | GPT-5.6 family (Sol, Terra, Luna) + GPT-5/legacy in ChatGPT; Codex on web/CLI/IDE/iOS; cloud integrations (code review, Slack) | Codex shares rolling 5-hour allowance + weekly caps with ChatGPT Work/Excel agentic features |
| Pro 5x | $100 | Everything in Plus + GPT-5.3-Codex-Spark preview + pro models | 5x Plus Codex usage |
| Pro 20x | $200 | Same, higher allowances | 20x Plus Codex usage; **new sign-ups/upgrades paused since Sept 10, 2026** |
| Business Standard | $25/user/mo ($20 annual) | ChatGPT + Codex across apps; SSO, MFA | Codex usage same as Plus (see table below) |
| Business Premium | $125/user/mo ($100 annual) | Higher Codex usage | [UNVERIFIED — multiplier not published] |

- No annual billing for Go/Plus/Pro personal plans.
- Sources: https://help.openai.com/en/articles/9793128-what-is-chatgpt-pro ; https://developers.openai.com/codex/pricing ; https://chatgpt.com/pricing

### 2b. Codex usage quotas (estimated local messages / 5-hour period)

| Model | Plus / Business Std | Pro 5x | Pro 20x |
|---|---|---|---|
| GPT-6 Astra | 5-45 | 25-225 | 100-900 |
| GPT-5.6 Sol | 10-100 | 50-500 | 200-2,000 |
| GPT-5.6 Terra | 25-200 | 125-1,000 | 500-4,000 |
| GPT-5.6 Luna | 250-2,000 | 1,250-10,000 | 5,000-40,000 |
| GPT-5.5 | 15-80 | 75-400 | 300-1,600 |
| GPT-5.4 | 20-100 | 100-500 | 400-2,000 |
| GPT-5.4 mini | 60-350 | 300-1,750 | 1,200-7,000 |

(OpenAI notes these are estimates, not fixed limits; cloud chats on ChatGPT plans use GPT-5.6 Sol and consume more allowance than local messages. Source: https://developers.openai.com/codex/pricing)

### 2c. API pricing ($/Mtok in / out)

| Model | Input | Output | Long-context (>200K) in/out | Cached input | Notes |
|---|---|---|---|---|---|
| gpt-5.3-codex (Fast) | $3.50 | $28.00 | — | — | ≈2x standard |
| gpt-5.3-codex | $1.75 | $14.00 | — | — | Codex model |
| gpt-5 | $1.25 | $10.00 | — | — | |
| gpt-5-mini | $0.25 | $2.00 | — | — | |
| gpt-5-nano | $0.05 | $0.40 | — | — | |
| GPT-6 Astra | $10.00 | $50.00 | $20/$75 | $1.00 | cache write $12.50/$25 |
| GPT-5.6 Sol | $4.00 | $20.00 | $8/$30 | — | Promotional pricing through Nov 21, 2026 |
| GPT-5.6 Terra | $2.00 | $12.00 | $4/$18 | — | |
| GPT-5.6 Luna | $0.20 | $1.20 | $0.40/$1.80 | — | |
| GPT-5.5 | $5.00 | $30.00 | — | — | |
| gpt-5.5-pro | $30.00 | $180.00 | — | — | |
| GPT-5.4 | $2.50 | $15.00 | — | — | |
| gpt-5.4-mini | $0.75 | $4.50 | — | — | |
| gpt-5.4-nano | $0.20 | $1.25 | — | — | |

- Batch & Flex processing = 50% discount; Fast mode ≈ 2x standard; data-residency routing adds 10% for models released on/after Mar 5, 2026.
- Source: https://developers.openai.com/api/docs/pricing

### 2d. API-equivalent value estimate [ESTIMATE]

| Tier | Price/mo | Value at API rates |
|---|---|---|
| Plus | $20 | Mid-range of Sol quota (≈50 msgs/5h) ≈ 5-25M tokens/mo of Sol-class usage ≈ $50-200 API-equivalent |
| Pro 5x | $100 | 5x Plus ≈ $250-1,000 API-equivalent if quota fully consumed, especially on Sol/Astra |
| Pro 20x | $200 | 20x Plus ≈ up to several thousand $ API-equivalent; currently paused for new sign-ups |

For a $100 budget, **Pro 5x via Codex CLI/OAuth is the highest-usage first-party option** if OpenAI models are preferred; Codex quota on Plus is often enough for light-to-moderate use.

---

## 3. Google

### 3a. Subscription tiers (Google AI Pro / Ultra — Antigravity)

| Tier | Price/mo | Model access | Usage limits |
|---|---|---|---|
| Free | $0 | Antigravity IDE basics | Limited |
| AI Pro | $19.99 | Gemini 3.x family, higher quotas vs free | ~15x free-tier quota in Antigravity [UNVERIFIED multiplier] |
| AI Ultra 5x | $99.99 | Gemini 3.x Pro + higher-priority models; 20TB storage | ~5x Pro token quota |
| AI Ultra 20x | $199.99 | Highest quota; 30TB storage | ~20x Pro token quota |

- Ultra repriced from $249.99 → $199.99 in May 2026 (source: https://antigravity.google/blog/changes-to-antigravity-plans).
- **Gemini CLI consumer/Google-login access was discontinued June 18, 2026**; the replacement for coding-agent use is the **Google Antigravity CLI**, which uses token-based 5-hour refresh + weekly limits (not prompt counts). Historical "Gemini CLI 1,000-1,500 requests/day" figures are obsolete.
- Sources: https://antigravity.google/plans ; https://antigravity.google/blog/changes-to-antigravity-plans

### 3b. Gemini API pricing ($/Mtok in / out)

| Model | Input | Output | Cache | Notes |
|---|---|---|---|---|
| Gemini 3.8 / 3.7 / 3.6 Flash | $0.75 | $3.75 | $0.075 cache + $0.50/Mtok-hr storage | Promo through Dec 31, 2026; then $1.50/$7.50 |
| Gemini 3.5 Flash | $1.50 | $9.00 | — | |
| Gemini 3.1 Pro Preview | $2.00 (≤200K) | $12.00 (≤200K) | — | >200K: $4/$18 |
| Gemini 2.5 Pro | $1.25 (≤200K) | $10.00 (≤200K) | — | >200K: $2.50/$15 |
| Gemini 2.5 Flash | $0.30 | $2.50 | — | [UNVERIFIED — verify current rate] |
| Gemini 3.5 / 3.1 Flash-Lite | ~$0.10/$0.38 class | | | [UNVERIFIED — exact rates from pricing page, verify] |

- Free tier: Flash-family only, free tokens but **content may be used for training**; ~20 requests/day, 5 RPM, 250K TPM for Flash models; ~500 RPD, 15 RPM for Flash-Lite [per-account; quotas vary]. Pro models are not on the free tier.
- Batch = 50% discount; Flex (latency-tolerant) = 50%; Priority ≈ 1.8x.
- API usage tiers: Free / Tier 1 ($10 per 10 min, $250 cap) / Tier 2 ($50/10min, $2,000 cap) / Tier 3 ($200/10min, $20K-$100K+ cap). RPD resets midnight Pacific.
- Sources: https://ai.google.dev/gemini-api/docs/pricing ; https://ai.google.dev/gemini-api/docs/rate-limits

### 3c. API-equivalent value estimate [ESTIMATE]

| Tier | Price/mo | Value |
|---|---|---|
| AI Pro ($19.99) | Modest quota | ~$20-60 API-equivalent at Flash promo rates |
| AI Ultra 5x ($99.99) | ~5x Pro quota | ~$100-300 API-equivalent at Flash rates; more if Pro-model quota included |
| AI Ultra 20x ($199.99) | ~20x Pro quota | ~$400-1,200+ API-equivalent at Flash rates |

Gemini 3.x Flash promo pricing ($0.75/$3.75) is the **cheapest capable pay-as-you-go coding API** among first parties in Sept 2026; for a $100/mo budget, pure API on Gemini Flash may beat a subscription unless heavy agentic usage demands Ultra.

---

## 4. xAI

### 4a. Subscription tiers (SuperGrok)

| Tier | Price/mo | Model access | Usage limits |
|---|---|---|---|
| SuperGrok Lite | ~$10 [UNVERIFIED — third-party reports, not on x.ai pricing page] | Grok access, lighter quotas | Light |
| SuperGrok | $30 | Grok 4.6 access, Grok Build | Weekly shared allowance across Chat/Imagine/Voice/Build; extra usage purchasable |
| SuperGrok Plus | $100 | Higher usage across Chat/Imagine/Voice/Build, 1080p video, priority | Higher weekly allowance |
| SuperGrok Heavy | $300 [price from x.ai plan comparison; corroborated by search] | Deepest Grok usage | Highest allowance |
| X Premium+ | $40 (or $395/yr ≈ $32.92/mo) | Includes SuperGrok access via X | help.x.com |

- Paid Grok plans use a **shared weekly allowance** across Chat, Imagine, Voice, and Build/coding; extra usage is purchasable (https://docs.x.ai/grok/faq).
- Business / Enterprise tiers exist by contacting sales.
- Sources: https://x.ai/pricing ; https://docs.x.ai/grok/faq ; https://help.x.com

### 4b. API pricing ($/Mtok in / out)

| Model | Input | Output | Cached input | >200K ctx in/out | Notes |
|---|---|---|---|---|---|
| grok-4.6 | $2.00 | $6.00 | $0.50 | $4/$12 | Flagship |
| grok-4.5 | $2.00 | $6.00 | $0.30 | — | Same token prices as 4.6 |
| grok-4.3 | $1.25 | $2.50 | — | $2.50/$5 | |
| grok-4.20 | $1.25 | $2.50 | — | $2.50/$5 | |
| grok-build-0.1 | $1.00 | $2.00 | — | $2/$4 | Agentic coding model; replaced retired grok-code-fast-1 on May 15, 2026 |

- Tool pricing: Web/X Search $5/1k calls (**X Search switching to per-result billing — $5/1k posts + $10/1k profiles — on Sept 21, 2026**); code execution $5/1k calls.
- No "Grok 5" API model listed as of Sept 2026; flagship is grok-4.6.
- Source: https://docs.x.ai/developers/pricing

### 4c. API-equivalent value estimate [ESTIMATE]

| Tier | Price/mo | Value |
|---|---|---|
| SuperGrok ($30) | Grok 4.6 + Grok Build weekly allowance | ~$30-90/mo equivalent at grok-4.6 rates |
| SuperGrok Plus ($100) | Higher weekly allowance | ~$100-300/mo equivalent at grok-4.6 rates |
| SuperGrok Heavy ($300) | Highest | ~$300-900+/mo equivalent |

**grok-build-0.1 at $1/$2 is the cheapest dedicated agentic-coding API model** among first parties — a strong pay-as-you-go option for a $100/mo coding budget when API-only usage is acceptable. SuperGrok subscription value depends heavily on how much of the shared weekly allowance coding (Build) gets vs chat/imagine/voice.

---

## 5. Mistral

### 5a. Subscription tiers (Vibe / La Plateforme)

| Tier | Price/mo | Model access | Usage limits |
|---|---|---|---|
| Experiment (free tier on La Plateforme) | $0 | Mistral models with rate limits (incl. Codestral) | Small monthly token allowance, throttled |
| Pro (Le Chat → "Vibe") | $14.99 | Mistral models via Vibe/Studio + **$15/mo API credits** usable across Vibe/Studio/API | Rate-limited; students $5.99/mo |
| Enterprise | by sales | All models, deployment options | Custom |

- Sources: https://mistral.ai/pricing ; https://docs.mistral.ai/inference/pricing

### 5b. API pricing ($/Mtok in / out)

| Model | Input | Output | Cached input |
|---|---|---|---|
| Mistral Large 3 | $0.50 | $1.50 | $0.05 |
| Mistral Medium 3.5 | $1.50 | $7.50 | — |
| Mistral Small 4 | $0.15 | $0.60 | — |
| Ministral 3 14B | $0.20 | $0.20 | — |
| Ministral 3 8B | $0.15 | $0.15 | — |
| Ministral 3 3B | $0.10 | $0.10 | — |
| Codestral | $0.30 | $0.90 | — |
| Devstral 2 | $0.40 | $2.00 | — | [UNVERIFIED — search-corroborated, not confirmed on live docs page] |
| Devstral 2 Small | $0.10 | $0.30 | — | [UNVERIFIED — same caveat] |
| Z.ai GLM 5.2 (hosted) | $1.40 | $4.40 | — |

- Batch = 50% discount; cached input up to 90% cheaper on supported models.
- Source: https://docs.mistral.ai/inference/pricing

### 5c. API-equivalent value estimate [ESTIMATE]

| Tier | Price/mo | Value |
|---|---|---|
| Pro ($14.99) | $15/mo API credits + Vibe/Studio access | ~$15 API-equivalent direct value; real value is bundled credits + chat |
| Pay-as-you-go API | — | Mistral Large 3 at $0.50/$1.50 and Devstral 2 at $0.40/$2 make Mistral the **cheapest per-token frontier-adjacent option** for coding; $100/mo buys roughly 60-100M mixed tokens |

---

## Cross-provider summary for a $100/mo coding budget

| Option | Cost | What you get |
|---|---|---|
| Claude Max 5x | $100 | ~5x Pro Claude Code usage; strong if Claude Code is your primary tool |
| ChatGPT Pro 5x (Codex) | $100 | 5x Plus Codex usage, up to ~50-500 Sol msgs/5h; best if OpenAI models preferred |
| Google AI Ultra 5x | $99.99 | ~5x Pro quota on Gemini 3.x; Antigravity CLI for coding |
| SuperGrok Plus | $100 | Higher Grok Build weekly allowance; shared with chat/voice/imagine |
| Pure API pay-as-you-go | $100 | e.g. ~50M in+out tokens on grok-build-0.1, or ~70M on Gemini 3.8 Flash promo (in-heavy mix), or ~35M Devstral 2; Mistral/Gemini Flash/xAI grok-build give the most tokens per dollar |

Time-sensitive flags (as of 2026-09-14):
- Gemini 3.6-3.8 Flash promo pricing ends **Dec 31, 2026** (doubles afterward).
- GPT-5.6 Sol promotional API pricing through **Nov 21, 2026**.
- ChatGPT Pro $200 (Pro 20x) new sign-ups/upgrades **paused since Sept 10, 2026**.
- X Search billing changes to per-result on **Sept 21, 2026**.
- Anthropic Sonnet 5 intro pricing made permanent Sept 2026.
- Gemini CLI consumer access discontinued June 18, 2026 → Antigravity CLI.

