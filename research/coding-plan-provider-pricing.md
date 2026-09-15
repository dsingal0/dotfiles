# Coding-Plan & Pay-As-You-Go Provider Pricing (omp providers)

Compiled: 2026-09-14. For the $100/month coding-budget optimization report.
Provider set cross-checked against the omp provider catalog in this repo
(`.omp-pricing-extract.json` — omp provider keys: `zai`, `zai-coding-plan`, `zhipuai-coding-plan`,
`alibaba`, `alibaba-cn`, `alibaba-token-plan`, `alibaba-coding-plan-cn`, `minimax`, `minimax-cn-coding-plan`,
`iflowcn`, `github-copilot`, `deepseek`, `openrouter`, `chutes`; Cursor is not an omp provider but omp can
consume Cursor provider API access, so it is included for comparison).

Prices are official-list, pre-tax, in USD unless noted (¥ = CNY). API-equivalent value estimates use each
provider's own published PAYG token rates; cache-heavy agentic coding (90%+ cache hit) is assumed where noted.

---

## 1. Moonshot Kimi — "Kimi for Coding" (kimi-for-coding)

Kimi Code is **not a standalone plan**: it is included in every Kimi membership tier and draws from the same
shared credit pool as Kimi's web/agent features. A split (separate Kimi Code subscription) has been announced
as "coming soon" — current subscribers keep merged benefits. ([kimi.ai membership benefits](https://www.kimi.ai/help/kimi-code/benefits))

### Membership tiers (international, USD)

| Tier | Price/month | Kimi Code | Notes |
|---|---:|---|---|
| Moderato | $19 | Included | Standard Code access |
| Allegretto | $39 | Included | Standard + HighSpeed |
| Allegro | $99 | Included | Standard + HighSpeed |
| Vivace | $199 | Included | Standard + HighSpeed |

Source: [kimi.ai membership overview](https://www.kimi.ai/help/membership/membership-overview). Official
per-tier prompt counts are **not published**; read limits from the in-app quota console.

### CN membership tiers (kimi.com, ¥)

| Tier | ¥/month | Agent credits (approx) |
|---|---:|---:|
| Andante | ¥49 | ~30 agent uses/mo |
| Moderato | ¥99 | ~60 |
| Allegretto | ¥199 | ~150 |
| Allegro | ¥699 | ~360 |

All tiers include Kimi Code; shared credit pool; Kimi Code additionally has its own 5-hour and weekly
usage caps layered on top of the credit pool. Source: [kimi.com membership pricing](https://www.kimi.com/help/membership/membership-pricing).

### Usage limits & multipliers

- Kimi Code credits refresh on a **7-day cycle** from subscription date (D1–D7, D8–D14, …); unused credits do not carry over.
- Two independent rate gates: **rolling 5-hour window** + **weekly quota**; either can block requests.
- Model multipliers (quota consumption): the 1M-context `k3` consumes ~2× the quota of `k3-256k`; **HighSpeed mode consumes ~3×** standard. ([kimi.com code docs](https://www.kimi.com/code/docs/en/))
- Community-measured official range: roughly **300–1,200 requests per rolling 5-hour window across plans** (not mapped to tiers publicly) [UNVERIFIED — community measurements from an older quota system].
- Overflow: **Extra Usage** pay-as-you-go balance, shared between Kimi web and Kimi Code, priced close to Kimi Open Platform API rates; top-up min ¥25, balance cap ¥10,000.

### PAYG API pricing ($/Mtok, [platform.kimi.com pricing](https://platform.kimi.com/docs/pricing/chat))

| Model | Input | Cached input | Output | Context |
|---|---:|---:|---:|---:|
| Kimi K3 (kimi-k3) | $3.00 | $0.30 | $15.00 | 1M |
| Kimi K2.7 Code (kimi-k2.7-code) | $0.95 | $0.19 | $4.00 | 256K |
| Kimi K2.6 | $00.95 [UNVERIFIED — third-party tables] | — | $4.00 [UNVERIFIED] | 256K |

### API-equivalent value estimate

At K2.7 Code rates ($0.95 in / $4 out) with a cache-heavy agent mix (~10:1 in:out, 90% cache hit), $19/mo
(Moderato) ≈ 25–35M input+output tokens of equivalent API value; $99/mo (Allegro) ≈ 5× that. Under HighSpeed
multipliers the effective value per API-dollar roughly triples in quota terms. [INFERENCE — derived from
published rates, not an official figure.]

---

## 2. Z.ai / Zhipu GLM Coding Plan (omp: `zai`, `zai-coding-plan`, `zhipuai-coding-plan`)

### International (z.ai / zcode.z.ai) — GLM Coding Plan

| Tier | Price/month | 5-hour credits | Weekly credits | Models |
|---|---:|---:|---:|---|
| Lite | $18 ($12.60/mo annual eff.) | 2,000 | 10,000 | GLM-5.3, GLM-5.3-Flash |
| Pro | $80 ($56/mo annual eff.) | 12,000 | 60,000 | GLM-5.3, GLM-5.3-Flash |
| Max | $168 ($117.60/mo annual eff.) | 28,000 | 140,000 | GLM-5.3, GLM-5.3-Flash |

Sources: [docs.z.ai devpack overview](https://docs.z.ai/devpack/overview), [zcode.z.ai](https://zcode.z.ai/en).

**Credit consumption (credits = (in×in-mult + cached×cache-mult + out×out-mult)/10,000):**

| Product | Input mult | Cached-input mult | Output mult |
|---|---:|---:|---:|
| GLM-5.3 | 6.9 | 1.7 | 24 |
| GLM-5.3-Flash (incl. vision MCP) | 2.3 | 0.56 | 8 |
| MCP: Web Search / Web Reader / Zread | — | — | 1.2 per call |

**Off-peak discount: 50% of standard credit rate**; peak = Mon–Fri 14:00–18:00 SGT (UTC+8). Z.ai claims up to
**92% savings vs PAYG** GLM-5.3 API when fully exploiting off-peak. Campaign (running as of Sep 2026):
23:00–09:00 daily, paid-plan users get **unlimited GLM-5.3-Flash** via ZCode + doubled quota on other agents
([campaign notice](https://docs.z.ai/devpack/notice/event-glm-5.3-flash)).

**Estimated weekly token allowance (95% cache hit, GLM-5.3):** Lite 48–97M, Pro 290–580M, Max 676–1,352M
(range = all-off-peak vs all-peak). Source: [docs.z.ai devpack overview](https://docs.z.ai/devpack/overview).

### China (bigmodel.cn — `zhipuai-coding-plan`)

Same credit structure (2,000/12,000/28,000 per 5h; 10k/60k/140k weekly). Prices as of Sep 2026 (raised from
the old ¥49/¥149/¥469 on 2026-07-31):

| Tier | ¥/month | ¥/quarter | ¥/year |
|---|---:|---:|---:|
| Lite | ¥118 | ¥283.2 | ¥991.2 |
| Pro | ¥538 | ¥1,291.2 | ¥4,519.2 |
| Max | ¥1,078 | ¥2,587.2 | ¥9,055.2 |

Sources: [bigmodel coding plan docs](https://zhipu-ef7018ed.mintlify.app/cn/coding-plan/overview), [creditsplan.cn](https://creditsplan.cn/brands/bigmodel/).

### PAYG API pricing ($/Mtok, [docs.z.ai pricing](https://docs.z.ai/guides/overview/pricing))

| Model | Input | Cached input | Output |
|---|---:|---:|---:|
| GLM-5.3 / GLM-5.2 / GLM-5.1 | $1.40 | $0.26 | $4.40 |
| GLM-5.3-Flash | $0.15 | $0.03 | $0.50 |
| GLM-5 | $1.00 | $0.20 | $3.20 |
| GLM-4.7 / GLM-4.6 / GLM-4.5 | $0.60 | $0.11 | $2.20 |
| GLM-4.7-FlashX | $0.07 | $0.01 | $0.40 |
| GLM-4.7-Flash / GLM-4.5-Flash | Free | Free | Free |
| Web Search tool | — | — | $0.01/use |

### API-equivalent value estimate

Pro ($80/mo) at published minimums (peak-only, 95% cache) ≈ 290M GLM-5.3 tokens/week ≈ 1.24B tokens/month;
at GLM-5.3 list price with a typical 90%-cache agent mix (~$0.55/Mtok blended) that is ≈ **$680/mo of API
value**; with off-peak 50% credits it doubles. Lite ($18) ≈ 48–97M tok/wk ≈ $115–230/mo API value.
[INFERENCE from Z.ai's own published allowance table + list prices.]

---

## 3. Alibaba — Qwen Coding Plan + Token Plan (omp: `alibaba-coding-plan-cn`, `alibaba-token-plan`, `alibaba`, `alibaba-cn`)

### Coding Plan (request-count quota)

| Tier | Price/month | Quota | Models |
|---|---:|---|---|
| Lite | discontinued 2026-03-20 (renewals ended 2026-04-13) | — | same model set as Pro |
| Pro | **$50** | 6,000 req/5h; 45,000/week; 90,000/month | qwen3.7-plus, qwen3.6-plus, kimi-k2.5, glm-5, MiniMax-M2.5, qwen3.5-plus, qwen3-max-2026-01-23, qwen3-coder-next, qwen3-coder-plus, glm-4.7 |

- Limited-quantity offering, restocked daily 00:00 UTC+8; may show sold out. Non-refundable.
- Quota is per **model call** (a simple task ≈ 5–10 calls; complex 10–30+). 5h quota rolls over continuously;
  weekly resets Monday 00:00 UTC+8; monthly resets on renewal date.
- Keys: Coding Plan key `sk-sp-…` + base `https://coding-intl.dashscope.aliyuncs.com/v1` (OpenAI) or
  `/apps/anthropic` (Anthropic). PAYG keys are not interchangeable.
- Interactive-tool use only; scripted/API-key automation outside the permitted scope risks suspension.

Source: [Alibaba Cloud Model Studio — Coding Plan](https://www.alibabacloud.com/help/en/model-studio/coding-plan).

### Token Plan (credit-based, Singapore region)

Personal Edition (7-day rolling credit window):

| Tier | Price/month | 7-day credits | Concurrent agents |
|---|---:|---:|---:|
| Lite | $6 (orig. $8) | 2,500 | 1–2 |
| Standard | $18 (orig. $25) | 10,000 | 3–4 |
| Pro | $68 (orig. $80) | 40,000 | 6–8 |
| Extra Bundle | $15/bundle (max 5) | 20,000, unlimited windows | — |

Team Edition (monthly credits): Standard seat $20/seat (25,000 credits), Pro seat $75/seat (100,000),
Max seat $200/seat (250,000), shared pack $700 (625,000). Sources:
[Token Plan overview](https://www.alibabacloud.com/help/en/model-studio/token-plan-overview),
[subscription guide](https://www.alibabacloud.com/blog/token-plan-individual-subscription-guide_603445).

Works with Qwen Code, Claude Code, Cursor, Codex, OpenClaw, Qoder, and any OpenAI/Anthropic-compatible tool.

### Qwen OAuth portal

The free Qwen-hosted OAuth tier for Qwen Code was **discontinued April 15, 2026**; OAuth is no longer
selectable in `/auth` and users are directed to Coding Plan, Token Plan, OpenRouter, Fireworks, Chutes, or
another API provider. Source: [qwen-code auth docs](https://github.com/QwenLM/qwen-code/blob/main/docs/users/configuration/auth.md).

### PAYG API pricing (DashScope, $/Mtok, from omp catalog)

| Model | Input | Output | Notes |
|---|---:|---:|---|
| qwen3-coder-plus | $1.00 | (tiered) | [UNVERIFIED exact out rate] |
| qwen3.7-max | $2.50 | $7.50 | |
| qwen3.7-plus | $0.40 | $1.60 | ≤256K ctx; $1.20/$4.80 above (per ClinePass reference table) |
| qwen3.7-flash | $0.03 | ~$0.12 [UNVERIFIED] | |

### API-equivalent value estimate

Coding Plan Pro $50/mo = up to 90,000 calls/mo; at ~10 calls/task and qwen3.7-plus-ish blended value
(~$0.50/Mtok blended [UNVERIFIED]), a token-heavy workload extracts roughly $200–500/mo of API value;
the request-count accounting (not tokens) makes light-token heavy-tool-use workloads the best fit.
[INFERENCE.]

---

## 4. MiniMax Coding Plan / Token Plan (omp: `minimax`, `minimax-cn-coding-plan`)

Renamed from "Coding Plan" to **Token Plan". International pricing:

| Tier | Price/month (docs) | Price (subscribe page) | 5-hour quota (M2.7 ref) | Agents |
|---|---:|---:|---:|---:|
| Plus | $22 | $20 | ~4,500 calls | 3–4 |
| Max | $55 | $50 | ~15,000 calls | 4–5 |
| Ultra | $132 | $120 | ~29,077 calls | 6–7 |

Docs/checkout price discrepancy ($22/$55/$132 vs $20/$50/$120) is live on MiniMax's own pages —
**verify at checkout**. Quota windows: 5-hour rolling + weekly; text/image/speech share one quota;
M2.7 shares quota with M3 (figures are M2.7-only estimates). Sources:
[pricing-token-plan](https://platform.minimax.io/docs/guides/pricing-token-plan), [subscribe page](https://platform.minimax.io/subscribe).

CN (minimaxi.com): Plus ¥49/mo, Max ¥119/mo, Ultra ¥469/mo; credits 1,000 = ¥7; PAYG M2.5 ¥2.1 in / ¥8.4 out
per Mtok (cache read ¥0.21, cache write ¥2.625). Sources: [CN token plan](https://platform.minimaxi.com/docs/guides/pricing-token-plan), [CN PAYG](https://platform.minimaxi.com/docs/guides/pricing-paygo).

### PAYG API pricing (platform.minimax.io, $/Mtok, from omp catalog)

| Model | Input | Output | Cache read | Cache write |
|---|---:|---:|---:|---:|
| MiniMax-M3 | $0.30 | $1.20 | $0.06 | — |
| MiniMax-M2.7 / M2.5 / M2.1 / M2 | $0.30 | $1.20 | $0.03–0.06 | $0.375 |
| MiniMax-M2.5-highspeed / M2.7-highspeed | $0.60 | $2.40 | $0.06 | $0.375 |

### API-equivalent value estimate

At M2.x blended ~$0.45/Mtok agent mix, Plus ($20) with ~4,500×3.4 windows/mo ≈ 100M+ tokens/mo ≈ **$45+/mo
API value**; Ultra ($120) ≈ 6× that. [INFERENCE — MiniMax publishes no official token-allowance table.]

---

## 5. GitHub Copilot (omp: `github-copilot`)

**Billing model changed June 1, 2026**: new subscriptions use **GitHub AI Credits** (1 credit = $0.01).
Premium-request multipliers now apply **only to legacy annual Pro/Pro+ subscribers** who stayed on the old
request-based system. Source: [billing change docs](https://docs.github.com/en/enterprise-cloud@latest/copilot/reference/copilot-billing/request-based-billing-legacy/what-changed-with-billing).

### Current plans (AI-credit billing)

| Plan | Price/month | AI credits/month | Completions |
|---|---:|---:|---|
| Free | $0 | allowance | 2,000/mo |
| Student | $0 (verified students) | allowance | — |
| Pro | $10 | 1,500 (1,000 base + 500 flex) | unlimited |
| Pro+ | $39 | 7,000 (3,900 base + 3,100 flex) | unlimited |
| Max | $100 | 20,000 (10,000 + 10,000) | unlimited |
| Business | $19/seat | 1,900/user | unlimited |
| Enterprise | $39/seat | 3,900/user | unlimited |

Overage: $0.01/credit; credits reset monthly, no rollover. Code completions/next-edit don't consume credits
on paid plans. Pro models: Claude Haiku 4.5/Sonnet 4.6/5, GPT-5 mini/5.4/5.3-Codex, Gemini Flash family;
Pro+/Max add Claude Opus 4.7/4.8/5, Fable 5/5.1, priority premium access. Sources:
[plans docs](https://docs.github.com/en/copilot/get-started/plans), [github.com/features/copilot/plans](https://github.com/features/copilot/plans).

### Legacy request-based billing (annual Pro/Pro+ only)

- Pro: 300 premium requests/mo; Pro+: 1,500; extra requests $0.04 each.
- Model multipliers (effective Jun 1, 2026): Claude Haiku 4.5 / GPT-4o / GPT-5 mini / Codex-Mini / Raptor mini / MAI-Code-1-Flash **0.33×**; GPT-5.1 / 5.1-Codex(-Max) **3×**; Claude Sonnet 4.5 / Gemini 3(.1) Pro **6×**; Claude Sonnet 4.6 **9×**; GPT-5.3-Codex / GPT-5.4(.mini) **6×**; Gemini 3.5 Flash **14×**; Claude Opus 4.5 **15×**; Claude Opus 4.6–4.8 **27×**; GPT-5.5 **57×**; code review 13×; auto-model −10%.
  Source: [legacy multipliers table](https://github.com/github/docs/blob/main/data/tables/copilot/annual-subscriber-model-multipliers.yml).

### API-equivalent value estimate

Pro+ $39 = 7,000 credits = **$70 of metered usage at $0.01/credit** (≈1.8× face value). Max $100 = $200 metered
(2×). What a credit buys varies by model (metered at provider-side rates); e.g. 7,000 credits ≈ 25–35M Claude
Sonnet-class tokens or several hundred M of flash-class tokens. [INFERENCE.]

---

## 6. Cursor (NOT an omp provider — included because omp can consume Cursor provider API access)

| Plan | Price/month | Included usage | Pools |
|---|---:|---|---|
| Hobby | Free | limited Agent usage | — |
| Pro | $20 | $20 API-agent usage + variable bonus | Cursor models / other models |
| Pro+ | $60 | $70 API-agent usage + variable bonus | same |
| Ultra | $200 | $400 API-agent usage + variable bonus | same |
| Teams Standard | $40/user | ≥$20/mo agent usage; pools not published as fixed dollars | Cursor pool + third-party API pool |
| Teams Premium | $120/user | 5× Standard usage | same |

On-demand overage at applicable API rates; no rollover; prices pre-tax. Sources:
[Cursor pricing](https://cursor.com/pricing), [pricing docs](https://prod.cursor.com/help/account-and-billing/pricing),
[Teams update Jun 2026](https://prod.cursor.com/blog/teams-pricing-june-2026).

API-equivalent value: Pro+ = 1.17× face; **Ultra = 2× face ($400 usage for $200)**; Pro = 1×.
Teams pool values [UNVERIFIED — not published as fixed dollar credits].

---

## 7. Cline / ClinePass

The Cline agent is free (BYOK or Cline's usage-based billing). ClinePass is the subscription:

| Tier | Price/month | Value | Limits |
|---|---:|---|---|
| ClinePass (only paid tier) | $9.99 | 2–5× standard API-rate usage of covered models | rolling 5-hour + calendar-week + calendar-month windows |
| Free tier | none permanent | rotating promotional free models, quota-limited | — |

Models covered (12 as of Sep 2026): GLM-5.3/5.2, Kimi K3/K2.7-Code/K2.6, MiniMax M3, Qwen3.8-Max/3.7-Max/3.7-Plus,
plus DeepSeek and MiMo models. Quota weighted by reference $/Mtok rates (GLM-5.3 $1.40/$4.40; Kimi K3 $3/$15;
K2.7-Code $0.95/$4.00; MiniMax M3 $0.30/$1.20; Qwen3.8-Max $2/$6; Qwen3.7-Max $2.50/$7.50; Qwen3.7-Plus
$0.40/$1.60 ≤256K). Cheaper models (MiniMax M3, Qwen3.7-Plus) stretch the subscription furthest.
Sources: [clinepass.mdx](https://github.com/cline/cline/blob/main/docs/getting-started/clinepass.mdx),
[cline.bot/pricing](https://cline.bot/pricing).

API-equivalent value: at the stated "2–5× API rates for $9.99", heavy use of the cheap models yields
roughly $20–50/mo of API-equivalent value. [INFERENCE — Cline publishes no fixed quota numbers.]

---

## 8. iFlow (omp: `iflowcn`)

- Publicly documented as **free** model market (no published PAYG price sheet or subscription tiers);
  enforcement is via concurrency and window limits rather than published quotas.
- **1 concurrent request per user** (HTTP 429 beyond); API keys valid ~7 days per CLI docs [UNVERIFIED exact validity].
- No fixed daily/monthly token quota published [UNVERIFIED community figures like "2M/day" — treat as unofficial].
- Models (API docs): Qwen3-Coder (256K ctx), KIMI-K2 (128K), DeepSeek-R1/V3, Qwen3-235B family, TBStars2-200B-A13B;
  CLI changelog adds GLM-5, GLM-4.7, Kimi K2.5, MiniMax-2.5, Qwen3 Max, DeepSeek 3.2, iFlow-Rome (CLI list ≠ API list).
- Endpoint: `https://apis.iflow.cn/v1/chat/completions` (OpenAI-compatible).
Sources: [docs.iflow.cn limits](https://docs.iflow.cn/zh-Hant/docs/limitSpeed), [docs.iflow.cn](https://docs.iflow.cn/zh-Hant/docs/), [platform.iflow.cn](https://platform.iflow.cn/en/).

API-equivalent value: effectively infinite $/token but single-concurrency makes it a bottleneck-limited fallback,
not a primary coding backend.

---

## 9. DeepSeek official API (omp: `deepseek`)

Two models; **off-peak = 50% of peak**; peak = Mon–Fri 01:00–04:00 and 06:00–10:00 UTC (all else off-peak,
including weekends). Source: [api-docs.deepseek.com pricing](https://api-docs.deepseek.com/quick_start/pricing/).

$/Mtok:

| Model | Input (cache hit) | Input (cache miss) | Output | Concurrency |
|---|---:|---:|---:|---:|
| deepseek-flash (V4.1-Flash) | $0.006 peak / $0.003 off | $0.30 peak / $0.15 off | $1.20 peak / $0.60 off | 2,500 |
| deepseek-v4-pro | $0.044 peak / $0.022 off | $1.32 peak / $0.66 off | $3.96 peak / $1.98 off | 500 |

Notes:

- `deepseek-flash` serves retired `deepseek-v4-flash` / `-vision-exp` aliases at Flash prices.
- V4 Pro was slated to stop Sep 14, 2026 but **service continues with unchanged billing** per the live pricing
  page; an earlier announcement said v4-pro requests would route to V4.1-Flash at Flash rates — live page says
  unchanged, so treat continued-Pro pricing as current but watch for changes. [partially UNVERIFIED — conflicting announcements]
- Context 1M, max output 384K; OpenAI + Anthropic-compatible base URLs; thinking mode default.
- Flash with 90% cache hit ≈ **$0.17/Mtok blended peak** — the cheapest first-party agentic-coding API in this set.

---

## 10. OpenRouter (omp: `openrouter`)

- **Per-generation pricing = provider list price, no OpenRouter markup.** Credit purchases carry a **5.5%
  platform fee** (8% for Business). Source: [openrouter.ai/pricing](https://openrouter.ai/pricing), [FAQ](https://openrouter.ai/docs/faq).
- **BYOK**: bring your own provider keys; **5% of equivalent list-price cost charged in credits only after the
  plan's monthly BYOK allowance** — PAYG allowance $25,000/mo of list-price inference, Enterprise $200,000/mo.
  (An earlier "1M free BYOK requests/mo" promo has been superseded by the allowance model.)
- Web tools: Exa / Parallel / Perplexity Search $0.005/request (+$0.001/result beyond 10); Firecrawl BYOK free;
  old `:online` suffix deprecated in favor of `openrouter:web_search` server tool.
- Relevant coding-model rates it passes through (from omp catalog): GLM-5.3 $1.40/$4.40, Kimi K3 $3/$15 (some
  listings $2/$10 [UNVERIFIED — variant-dependent]), DeepSeek V4-Flash $0.15/$0.60 (cache read $0.003),
  MiniMax M2.5 $0.30/$1.20, Qwen3-Coder ~$0.13–0.30/$0.40–1.00 depending on variant.
- API-equivalent value: at $100/mo budget, effective spend ≈ $94.70 of inference after the 5.5% credit fee;
  BYOK usage below allowance is $0-fee routing.

---

## 11. Chutes (chutes.ai) (omp: `chutes`)

All featured models on confidential TEE GPUs; **pay per token, no markup**. Optional monthly plans:

| Plan | Price/month | Benefit |
|---|---:|---|
| Plus | $10 | bundled daily request quota + 6% off PAYG rates beyond quota |
| Pro | $20 | larger daily quota + 10% off PAYG rates beyond quota |

Private TEE GPU deployments: GPU hourly rate (one self-serve verified class; ~$1.80/hr shown at time of
research [UNVERIFIED — fluctuates]) + one-time fee = 3× hourly rate. Source: [chutes.ai/pricing](https://chutes.ai/pricing).

PAYG $/Mtok (from omp catalog, chutes TEE endpoints):

| Model | Input | Output | Cache read |
|---|---:|---:|---:|
| Kimi K3 TEE | $3.00 | $15.00 | $0.30 |
| GLM-5.2 TEE | $1.25 | $3.95 | $0.125 |
| GLM-5.1 TEE | $0.98 | $3.08 | $0.098 |
| DeepSeek V4-Flash-0731 TEE | $0.44 | $1.32 | $0.044 |
| Qwen3.5-397B-A17B TEE | $0.45 | $3.00 | $0.045 |
| Kimi K2.6 TEE | $0.58 | $3.40 | $0.058 |
| Qwen3.8-27B TEE | $0.32 | $2.50 | $0.032 |
| Qwen3-32B TEE | $0.104 | $0.416 | $0.0104 |
| Nemotron-3-Nano-Omni-30B TEE / Mistral-Nemo TEE | $0.0245 | $0.0978 | $0.00245 |

Note: Chutes TEE rates carry a premium over first-party APIs (e.g. DeepSeek Flash $0.44/$1.32 vs $0.15/$0.60
first-party) — you pay for confidential compute, not for cheapness.

---

## Budget-fit snapshot ($100/month)

| Provider / plan | Price | Best-for note |
|---|---:|---|
| Z.ai GLM Coding Plan Pro | $80 | highest published token allowance per $ (290–580M tok/wk GLM-5.3) |
| GitHub Copilot Max | $100 | $200 metered-credit face value (2× face) |
| Cursor Ultra | $200 | over budget; Pro+ $60 = $70 usage |
| Kimi Allegro | $99 | K2.7-Code/K3 via omp; 5h+weekly caps |
| MiniMax Token Plan Max | $50–55 | M2.x at $0.30/$1.20 is the cheapest strong agent API |
| Alibaba Token Plan Pro | $68 | multi-model credits incl. Qwen+GLM+Kimi+MiniMax; coding-plan endpoint ($50, limited slots) |
| ClinePass | $9.99 | cheapest multi-vendor open-model pass |
| DeepSeek Flash PAYG | usage | ~$0.17/Mtok blended peak with caching; no sub needed |
| Chutes Plus/Pro | $10/$20 | TEE privacy niche; PAYG above first-party rates |

[Snapshot rows are INFERENCE-grade synthesis for the aggregator's optimization report.]
