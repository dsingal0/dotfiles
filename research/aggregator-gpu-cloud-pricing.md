# Aggregator & GPU-Cloud Provider Pricing — omp-Supported Providers

**Date:** September 2026 · **Purpose:** Pricing data pack for the $100/month coding-budget optimization report.
**Units:** USD per million tokens ($/Mtok). "cached" = cached/prompt-cache input rate. Sources cited inline; anything not confirmed on an official pricing page is marked **[UNVERIFIED]**.

Provider classification:

- **Aggregators** — route to many providers; fee is on deposits or a % of spend, model prices passed through at list.
- **GPU clouds / per-token inference hosts** — operate their own (or dedicated) infra and publish per-token rate cards.
- **Flat-subscription providers** — fixed $/month for a token/request allowance (plus overage rates).

---

## 1. Aggregators (routing + fee/markup, no/low per-token markup)

### 1.1 OpenRouter

- **Model:** prepaid USD credits; deducts provider cost at list price — **no per-token markup** on normal usage. Platform fee charged at credit purchase: **5.5% (min $0.80)** card, **5%** crypto. Source: https://openrouter.ai/docs/faq and https://openrouter.ai/pricing
- **Effective overhead on a $100 monthly budget:** ~5.5% ⇒ ~$94.8 of spendable credits (if topped up monthly in one purchase).
- **Free tier:** 50 free-model requests/day; **1,000/day** after buying ≥$10 credits. Source: https://openrouter.ai/docs/faq
- **BYOK:** pricing page says **$25,000/month of list-price inference free, then 5% of list price** (enterprise: $200k/mo, then 5%). The FAQ still describes "first 1M BYOK requests/mo free, then 5%" — the two descriptions are inconsistent; confirm with OpenRouter before relying on either. **[UNVERIFIED — which allowance applies]**
- **Model pricing:** full pass-through, per-provider rates, incl. `input_cache_read`/`input_cache_write`. Live rates via `https://openrouter.ai/api/v1/models`. Extra charges: hosted web search ~$0.005/request; per-request/per-image fees on some models. Sources: https://openrouter.ai/docs/guides/overview/models, https://openrouter.ai/docs/guides/features/server-tools/web-search
- **API-equivalent value:** ≈ list price of the underlying provider ÷ 0.945 (card top-up).

### 1.2 Vercel AI Gateway

- **Model:** **0% token markup** — bills at listed provider/model rates, including with your own provider key. $5 free credits per 30 days for accounts that have never paid. Source: https://vercel.com/docs/ai-gateway/pricing
- **Example rates on gateway** ($/Mtok in/out; cached where listed):

| Model | In | Cached in | Out | Source |
|---|---:|---:|---:|---|
| DeepSeek V4.1 Flash | $0.15 | $0.003 | $0.60 | https://vercel.com/ai-gateway/models/deepseek-v4.1-flash |
| DeepSeek V4 Flash | $0.08 | $0.007 | $0.18 | https://vercel.com/ai-gateway/models/deepseek-v4-flash |
| GLM 5.3 | $0.70 | — | $2.20 | https://vercel.com/ai-gateway/models/glm-5.3 |
| GLM 5.3 Flash | $0.05* | — | $0.20* | https://vercel.com/ai-gateway/models/glm-5.3-flash (*promo 50%-off listing; provider table also shows Z.AI at $0.08/$0.25 **[UNVERIFIED — which rate applies at checkout]**) |

- **API-equivalent value:** 1:1 with provider list price — the cheapest "zero-markup" aggregator for coding use.

### 1.3 NanoGPT

- **API:** list prices, **no markup, no deposit fees**. Source: https://nano-gpt.com/pricing and https://docs.nano-gpt.com/api-reference/miscellaneous/pricing
- **Subscription (see §3.3):** $12/mo, 60M input tokens/week.
- **API-equivalent value:** 1:1 list pass-through.

### 1.4 Hugging Face Inference Providers

- **PRO plan:** **$9/month**, includes **$2/month compute credits**; routed requests billed at the underlying provider's rate with **no HF markup**. Credits only apply to HF-routed billing, not your own provider keys. Sources: https://huggingface.co/pricing, https://huggingface.co/docs/inference-providers/pricing
- **Sample provider rates via the router:** Llama 3.1 8B (Novita) $0.02/$0.05; GPT-OSS-120B (Novita) $0.05/$0.25, (Together) $0.15/$0.60; DeepSeek V4 Pro (DeepInfra) $1.30/$2.60, (Novita) $1.60/$3.20; Kimi K3 (Together) $3.00/$15.00. Source: https://huggingface.co/docs/inference-providers/pricing
- **API-equivalent value:** $2 credits ≈ up to ~40M output tokens on the cheapest hosted models, or ~0.77M output tokens on DeepSeek V4 Pro — negligible for a $100 coding budget; useful mainly for the routing API itself.

---

## 2. GPU clouds / per-token inference providers

### 2.1 Flagship coding-model rate card across providers ($/Mtok in / cached in / out)

All rates from official pricing pages (Sept 2026) unless flagged.

**DeepSeek family**

| Model | Provider | In | Cached | Out | Source |
|---|---|---:|---:|---:|---|
| DeepSeek V4 Flash | DeepInfra | $0.09 | $0.018 | $0.18 | https://deepinfra.com |
| DeepSeek V4 Flash | Together | $0.14 | $0.03 | $0.28 | https://www.together.ai/pricing |
| DeepSeek V4 Flash | SiliconFlow | $0.13 | $0.028 | $0.28 | https://www.siliconflow.com/pricing |
| DeepSeek V4 Flash 0731 | Baseten | $0.13 | $0.028 | $0.26 | https://www.baseten.co/pricing/ |
| DeepSeek V4 Flash 0731 | CoreWeave | $0.13 | $0.07 | $0.28 | https://coreweave.com/products/serverless-inference |
| DeepSeek V4 Flash | Crusoe | $0.14 | $0.03 | $0.28 | https://www.crusoe.ai/cloud/pricing |
| DeepSeek V4.1 Flash | DeepInfra | $0.20 | $0.006 | $0.60 | https://deepinfra.com |
| DeepSeek V4.1 Flash | Together | $0.30 | $0.006 | $1.20 | https://www.together.ai/pricing |
| DeepSeek V4.1 Flash | Ollama Cloud | $0.15 | $0.003 | $0.60 | https://ollama.com/pricing |
| DeepSeek V4 Pro | DeepInfra | $1.30 | $0.10 | $2.60 | https://deepinfra.com |
| DeepSeek V4 Pro | Novita | $1.60 | $0.135 | $3.20 | https://novita.ai/en/console/pricing-console |
| DeepSeek V4 Pro | SiliconFlow | $1.50 | $0.135 | $3.14 | https://www.siliconflow.com/pricing |
| DeepSeek V4 Pro | Crusoe | $1.74 | $0.15 | $3.48 | https://www.crusoe.ai/cloud/pricing |
| DeepSeek V4 Pro 0813 | Baseten | $1.32 | $0.132 | $3.96 | https://www.baseten.co/pricing/ |
| DeepSeek V4 Pro 0813 | Together | $1.32 | $0.13 | $3.96 | https://www.together.ai/pricing |
| DeepSeek V4 Pro 0813 | Novita | $1.32 | $0.044 | $3.96 | https://novita.ai/en/console/pricing-console |
| DeepSeek V4 Pro 0813 | Fireworks | $1.32 | — | $3.96 | https://docs.fireworks.ai/serverless/pricing |
| DeepSeek V4 Pro 0813 | CoreWeave | $1.31 | $0.044 | $3.96 | https://coreweave.com/products/serverless-inference |
| DeepSeek V4 Pro 0813 | Ollama Cloud | $0.66 | $0.022 | $1.98 | https://ollama.com/pricing (notably cheapest; **[UNVERIFIED — verify against dashboard, appears to be an off-peak rate with $1.32 peak per NanoGPT-reported DeepSeek peak/off-peak structure]**) |

**Kimi family (Moonshot)**

| Model | Provider | In | Cached | Out | Source |
|---|---|---:|---:|---:|---|
| Kimi K3 | Baseten | $3.00 | $0.30 | $15.00 | https://www.baseten.co/pricing/ |
| Kimi K3 | Together | $3.00 | $0.30 | $15.00 | https://www.together.ai/pricing |
| Kimi K3 | Novita | $3.00 | $0.30 | $15.00 | https://novita.ai/en/console/pricing-console |
| Kimi K3 | SiliconFlow | $2.70 | $0.27 | $13.50 | https://www.siliconflow.com/pricing |
| Kimi K3 | Ollama Cloud | $3.00 | $0.30 | $15.00 | https://ollama.com/pricing |
| Kimi K3 | DeepInfra | $2.85 | $0.285 | $14.25 | https://deepinfra.com |
| Kimi K2.6 | Baseten | $0.95 | $0.16 | $4.00 | https://www.baseten.co/pricing/ |
| Kimi K2.6 | DeepInfra | $0.75 | $0.15 | $3.50 | https://deepinfra.com |
| Kimi K2.6 | Novita | $0.80 | $0.16 | $3.40 | https://novita.ai/en/console/pricing-console |
| Kimi K2.6 | SiliconFlow | $0.77 | $0.14 | $3.40 | https://www.siliconflow.com/pricing |
| Kimi K2.6 | Crusoe | $0.70 | $0.35 | $3.50 | https://www.crusoe.ai/cloud/pricing |
| Kimi K2.7 Code | Baseten | $0.95 | $0.16 | $4.00 | https://www.baseten.co/pricing/ |
| Kimi K2.7 Code | DeepInfra | $0.68 | $0.136 | $3.40 | https://deepinfra.com |
| Kimi K2.7 Code | Novita | $0.95 | $0.19 | $4.00 | https://novita.ai/en/console/pricing-console |
| Kimi K2.7 Code | Ollama Cloud | $0.95 | $0.19 | $4.00 | https://ollama.com/pricing |
| Kimi K2.7 Code | SiliconFlow | $0.86 | $0.18 | $3.80 | https://www.siliconflow.com/pricing |
| Kimi K2.7 Code | CoreWeave | $0.71 | $0.15 | $3.50 | https://coreweave.com/products/serverless-inference |

**GLM family (Z.ai)**

| Model | Provider | In | Cached | Out | Source |
|---|---|---:|---:|---:|---|
| GLM 5.3 | Baseten | $1.40 | $0.14 | $4.40 | https://www.baseten.co/pricing/ |
| GLM 5.3 | Together | $1.40 | $0.26 | $4.40 | https://www.together.ai/pricing |
| GLM 5.3 | Fireworks | $1.40 | — | $4.40 | https://docs.fireworks.ai/serverless/pricing |
| GLM 5.3 | Novita | $1.40 | $0.26 | $4.40 | https://novita.ai/en/console/pricing-console |
| GLM 5.3 | DeepInfra | $1.20 | $0.12 | $4.00 | https://deepinfra.com |
| GLM 5.3 | Ollama Cloud | $1.40 | $0.26 | $4.40 | https://ollama.com/pricing |
| GLM 5.2 | CoreWeave | $0.76 | $0.14 | $2.42 | https://coreweave.com/products/serverless-inference |
| GLM 5.3 | Tinfoil | $2.52 | — | $8.05 | **[UNVERIFIED — third-party snapshot, https://privateer.pro/api-pricing]** |
| GLM 5.3 Flash | DeepInfra | $0.075 | $0.015 | $0.25 | https://deepinfra.com |
| GLM 5.3 Flash | Baseten | $0.15 | $0.03 | $0.50 | https://www.baseten.co/pricing/ |
| GLM 5.3 Flash | Together | $0.15 | $0.03 | $0.50 | https://www.together.ai/pricing |
| GLM 5.3 Flash | Fireworks | $0.15 | — | $0.50 | https://docs.fireworks.ai/serverless/pricing |
| GLM 5.3 Flash | Novita | $0.15 | $0.03 | $0.50 | https://novita.ai/en/console/pricing-console |
| GLM 5.3 Flash | SiliconFlow | $0.15 | $0.03 | $0.50 | https://www.siliconflow.com/pricing |
| GLM 5.3 Flash | CoreWeave | $0.15 | $0.05 | $0.50 | https://coreweave.com/products/serverless-inference |
| GLM 5.3 Flash | Crusoe | $0.15 | $0.03 | $0.50 | https://www.crusoe.ai/cloud/pricing |
| GLM 5.2 / 5.2 Fast | Baseten | $1.40 / $2.10 | $0.14 / $0.21 | $4.40 / $6.60 | https://www.baseten.co/pricing/ |
| GLM 4.7 | Baseten | $0.60 | $0.12 | $2.20 | https://www.baseten.co/pricing/ |
| GLM 4.7 | Cerebras | ~$2.25 | — | ~$2.75 | **[UNVERIFIED — third-party listing, not on Cerebras's rendered price table]** |

**Qwen family**

| Model | Provider | In | Cached | Out | Source |
|---|---|---:|---:|---:|---|
| Qwen3.8 Flash | Together | $0.15 | — | $0.47 | https://www.together.ai/pricing |
| Qwen3.8 Flash | Novita | $0.15 | $0.016 | $0.47 | https://novita.ai/en/console/pricing-console |
| Qwen3.8 27B | Groq | $0.60 | — | $3.00 | https://console.groq.com/docs/models (preview) |
| Qwen3.8 27B | CoreWeave | $0.40 | $0.15 | $3.00 | https://coreweave.com/products/serverless-inference |
| Qwen3.7 Plus | Together | $0.32 | — | $1.28 | https://www.together.ai/pricing |
| Qwen3.7 Plus | Fireworks | $0.50 | — | $3.00 | https://docs.fireworks.ai/serverless/pricing **[UNVERIFIED — Together and Fireworks list different "Plus" rates; verify model ID]** |
| Qwen3.7/3.8 Max | Together / Fireworks | $2.00 | $0.25 | $6.00 | https://www.together.ai/pricing, https://docs.fireworks.ai/serverless/pricing |
| Qwen3.8 2.4T A95B | Together | $2.00 | $0.25–$0.50* | $6.00 | *pricing page vs catalog disagree on cache rate **[UNVERIFIED]** |
| Qwen3.8 2.4T A95B | DeepInfra | $2.00 | $0.20 | $6.00 | https://deepinfra.com |

**Llama 4 / Llama 3.3 and GPT-OSS**

| Model | Provider | In | Cached | Out | Source |
|---|---|---:|---:|---:|---|
| GPT-OSS-120B | Groq | $0.15 | $0.075 | $0.60 | https://console.groq.com/docs/models |
| GPT-OSS-120B | CoreWeave | $0.03 | — | $0.17 | https://coreweave.com/products/serverless-inference |
| GPT-OSS-120B | Crusoe | $0.05 | $0.05 | $0.20 | https://www.crusoe.ai/cloud/pricing |
| GPT-OSS-120B | Venice | $0.07 | — | $0.30 | https://docs.venice.ai/overview/pricing |
| GPT-OSS-120B | Tinfoil | $0.21 | — | $0.84 | **[UNVERIFIED — third-party snapshot]** |
| GPT-OSS-20B | Groq | $0.075 | $0.037 | $0.30 | https://console.groq.com/docs/models |
| GPT-OSS-20B | CoreWeave | $0.03 | — | $0.13 | https://coreweave.com/products/serverless-inference |
| Llama 4 Scout | Cerebras | $0.65 | — | $0.85 | https://www.cerebras.ai/blog/ninjatechdeepresearch (older announcement **[UNVERIFIED — current availability]**) |
| Llama 3.3 70B | CoreWeave | $0.71 | — | $0.71 | https://coreweave.com/products/serverless-inference |
| Llama 3.3 70B | Nebius | $0.13 | — | $0.40 | https://nebius.com/token-factory/prices |
| Llama 3.3 70B | Cerebras | $0.85 | — | $1.20 | historical Cerebras pricing table **[UNVERIFIED — current rate]** |

**Nemotron / Inkling**

| Model | Provider | In | Cached | Out | Source |
|---|---|---:|---:|---:|---|
| NVIDIA Nemotron 3 Ultra | Baseten | $0.60 | $0.12 | $2.40 | https://www.baseten.co/pricing/ |
| NVIDIA Nemotron 3 Ultra | CoreWeave | $0.75 | $0.15 | $2.75 | https://coreweave.com/products/serverless-inference |
| Nemotron 3.5 Lightning | CoreWeave | $0.10 | $0.05 | $0.25 | https://coreweave.com/products/serverless-inference |
| Nemotron 3.5 Lightning | Crusoe | $0.05 | $0.20* | $0.03 | *row as reported; in/cached/out ordering in source table ambiguous **[UNVERIFIED]** |
| Inkling | Baseten | $1.00 | $0.17 | $4.05 | https://www.baseten.co/pricing/ and https://www.baseten.co/library/inkling/ |

### 2.2 Provider-by-provider notes

**Groq** — Pay-as-you-go per-token; Llama 3.1/3.3 models moved to "Contact Sales" with deprecation announced Aug 16, 2026; current catalog centers on GPT-OSS 20B/120B ($0.075/$0.30 and $0.15/$0.60; cache 50% of input) and Qwen 3.6/3.8 27B previews ($0.60/$3.00, $0.80/$4.00). No GLM hosted. Rate limits are tier-based (free/dev/pay-go). Sources: https://console.groq.com/docs/models, https://console.groq.com/docs/deprecations, https://console.groq.com/docs/rate-limits. Dev-tier pricing beyond public rate cards: **[UNVERIFIED — not published]**.

**Cerebras** — Two products: (a) per-token PayGo API (current native docs list Qwen 3.8 27B and GPT-OSS 120B as PayGo models; rates not visible in rendered docs — **[UNVERIFIED]**); (b) flat Code/Developer plans (see §3.1). Sources: https://inference-docs.cerebras.ai/support/pricing, https://inference-docs.cerebras.ai/models/overview, https://www.cerebras.ai/pricing.

**Baseten** — Model APIs at per-token rates (table above); Basic plan $0/month + usage; cached-input pricing applied automatically on prefix hits; also offers dedicated deployments billed per GPU-minute. Sources: https://www.baseten.co/pricing/, https://docs.baseten.co/inference/model-apis/overview.

**Together AI** — Serverless usage-based, no minimums; dedicated/Pro tiers priced per GPU-hour (not published in the summary — **[UNVERIFIED]**). Rates in table above. Source: https://www.together.ai/pricing, https://docs.together.ai/docs/serverless/models.

**Fireworks AI** — Serverless per-token; batch inference at 50% of standard rates. Sources: https://docs.fireworks.ai/serverless/pricing, https://fireworks.ai/models?modelTypes=Serverless&show=serverless.

**DeepInfra** — Pay-as-you-go per-token; promotional discounts (35–50% off) rotate on some models. Source: https://deepinfra.com.

**Novita** — Per-token with explicit cache-read column; batch at 50% (introductory). Also sells a flat coding plan (see §3.5). Source: https://novita.ai/en/console/pricing-console.

**SiliconFlow** — Per-token with cache column; prices occasionally carry FX-derived odd decimals ($1.50162 in, etc.). Source: https://www.siliconflow.com/pricing.

**NVIDIA NIM (build.nvidia.com)** — Hosted NIM endpoints free for prototyping/dev under the Developer Program (no per-token price published); production requires NVIDIA AI Enterprise (~$4,500/GPU/year, ~$1/GPU-hr cloud). Not a viable per-token budget line. Sources: https://docs.api.nvidia.com/nim/docs/product, https://build.nvidia.com/models.

**CoreWeave** — Serverless Inference (OpenAI-compatible) per-token; dedicated inference billed per GPU-hour. Notably aggressive GPT-OSS pricing ($0.03 in). Sources: https://coreweave.com/products/serverless-inference, https://docs.coreweave.com/products/inference/billing.

**Nebius (Token Factory / AI Studio)** — Per-token with "base" and "fast" tiers; batch at 50% of base. Public catalog still centers on DeepSeek V3.x/R1 (e.g., V3 $0.50/$1.50 base, $0.75/$2.25 fast; R1-0528 $0.80/$2.40), GLM-4.5 ($0.60/$2.20), Qwen3-235B ($0.20/$0.60–$0.80), Llama 3.3 70B ($0.13/$0.40) — no V4/K3/GLM-5.x rates published yet. Sources: https://nebius.com/token-factory/prices, https://docs.tokenfactory.nebius.com.

**Crusoe** — Serverless per-token (DeepSeek V4 Pro $1.74/$3.48, V4 Flash $0.14/$0.28, GPT-OSS-120B $0.05/$0.20, Kimi K2.6 $0.70/$3.50, GLM 5.3 Flash $0.15/$0.50); self-serve dedicated at $5.50/hr H100, $6.00/hr H200; $5 free credits. Llama 3.3 70B and Qwen3 235B in catalog but rates not published. Sources: https://www.crusoe.ai/cloud/pricing, https://docs.cloud.crusoe.ai/serverless-inference/index.html.

**Tinfoil** — Private-enclave per-token inference; official pricing page does not expose a public rate table. Third-party snapshot (Sept 10, 2026) shows ~1.7–2.8× list-price premiums (e.g., GPT-OSS-120B $0.21/$0.84, DeepSeek V4 Flash $0.42/$0.98, GLM 5.3 Flash $0.56/$1.75, Kimi K3 $5.60/$28.00) — the premium is for attested confidential inference. Secure prompt caching introduced July 2026 (rate undisclosed). Source: https://tinfoil.sh/inference, https://tinfoil.sh/blog/2026-07-14-secure-prompt-caching, snapshot https://privateer.pro/api-pricing — **all Tinfoil rates [UNVERIFIED]**.

**Modal** — Not a rate-card host: dedicated GPU serving at per-second rates (H100 $3.95/hr, H200 $4.54/hr, B200 $6.25/hr, L4 $0.80/hr; CPU $0.0000131/core-sec, RAM $0.00000222/GiB-sec) plus per-token shared endpoints. A high-throughput Qwen3-8B-on-H100 benchmark worked out to ~$0.04/Mtok — utilization-dependent. Source: https://modal.com/pricing, https://modal.com/docs/guide/endpoints.

**Venice** — Per-token API (e.g., DeepSeek V4 Flash $0.14/$0.28 1M ctx, Kimi K2.5 $0.56/$3.50, Qwen3 Coder 480B $0.35/$1.50, Mercury 2.5 $0.05/$0.19) plus privacy-focused subscriptions (see §3.6). Source: https://docs.venice.ai/overview/pricing.

---

## 3. Flat-subscription providers

### 3.1 Cerebras Code / Developer plans

- **Code Pro: $50/month** — up to **24M tokens/day** on Cerebras Code (GLM 4.7), ≈ 720M tokens/month ⇒ effective **~$0.069/Mtok** at full utilization. Source: https://www.cerebras.ai/code
- **Developer (free) tier:** exists with lower limits; exact current quotas not published in accessible docs — **[UNVERIFIED]**. Source: https://inference-docs.cerebras.ai/support/rate-limits
- **API-equivalent value:** at GLM 4.7 Baseten rates ($0.60/$2.20), 720M tokens (say 4:1 in:out ≈ 576M in/144M out) ≈ $662/month of API value — the strongest flat-plan value for heavy coding, contingent on actually using ~24M tokens/day.

### 3.2 Ollama Cloud

| Plan | $/month | Included usage | Concurrency |
|---|---:|---:|---:|
| Free | $0 | starter credits (unspecified) | 1 |
| Pro | $20 | **$60** of usage | 3 |
| Max | $100 | **$300** of usage | 10 |
| Team | $500 | $1,000 shared | 10 |

- Credits are dollar-denominated, consumed at per-token rates (rate card in §2.1; e.g., gpt-oss:120b $0.15/$0.60, GLM-5.3 $1.40/$4.40, Kimi K3 $3.00/$15.00); no rollover; DeepSeek peak pricing 12:00–18:00 UTC weekdays. Source: https://ollama.com/pricing
- **API-equivalent value:** Pro returns 3× the subscription price in usage; Max returns 3× — i.e., a $100 budget on Max yields $300 of list-rate inference.

### 3.3 NanoGPT subscription

- **$12/month:** **60M input tokens/week** (~260M input/month) on most open-weight models (GLM, Kimi, DeepSeek, MiniMax, etc.), 100 images/day; cached input still consumes quota; some models carry a 2× multiplier (halving effective quota); resets Mondays 00:00 UTC. Sources: https://nano-gpt.com/pricing, https://nano-gpt.com/blog/subscription-update-february-2026, https://infrabase.ai/inference-apis/nanogpt
- **API-equivalent value:** 260M input on GLM-5.3 ($1.40/M) ≈ $364; on Kimi K2.7 Code ($0.95/M) ≈ $247; on Kimi K3 ($3.00/M) ≈ $780. Whether output tokens are metered on the sub is unclear — community reports conflict **[UNVERIFIED]**. Either way, order-of-magnitude the best $-per-input-token flat deal, with the caveat that agent workloads re-send history (all counted, cached included).

### 3.4 Hugging Face PRO (aggregator flat tier)

- $9/mo incl. $2 usage credits — see §1.4. Source: https://huggingface.co/pricing

### 3.5 Novita coding plan

- Novita advertises a flat **coding plan** alongside PAYG (GLM/Kimi/DeepSeek models); current tier prices not published on the pricing console — **[UNVERIFIED — see https://novita.ai/coding-plan]**.

### 3.6 Venice subscriptions

| Plan | $/month | Credits (100 = $1) | API value | Rollover |
|---|---:|---:|---:|---|
| Pro | $18 | 100 | ~$1 | none |
| Pro Plus | $68 | 7,500 | ~$75 | 2 months |
| Max | $200 | 22,500 | ~$225 | 3 months |

- "Unlimited text" applies only to the Venice app, not the API; API usage is metered per token against credits. Annual billing −10%. Sources: https://venice.ai/pricing, https://venice.ai/faqs/all
- **API-equivalent value:** Pro Plus ≈ $75 of per-token usage for $68 (marginal); Max ≈ $225 for $200. The value is privacy, not discount.

---

## 4. Budget-relevant summary (for the $100/month report)

- **Cheapest per-token coding stack (uncached):** CoreWeave GPT-OSS-120B $0.03/$0.17; DeepInfra GLM-5.3-Flash $0.075/$0.25; DeepInfra DeepSeek V4 Flash $0.09/$0.18; Ollama/CoreWeave DeepSeek V4.1 Flash ~$0.15/$0.60.
- **Cheapest flagship-model rates:** GLM 5.3 via CoreWeave GLM-5.2 ($0.76/$2.42) or DeepInfra ($1.20/$4.00); Kimi K2.7 Code via DeepInfra ($0.68/$3.40); DeepSeek V4 Pro via DeepInfra ($1.30/$2.60); Kimi K3 cheapest at SiliconFlow ($2.70/$13.50) — K3 is expensive everywhere.
- **Zero-markup aggregators:** Vercel AI Gateway (0%), NanoGPT API (0%), HF router (0%); OpenRouter costs ~5.5% on deposit only.
- **Best flat plans by API-equivalent value at full utilization:** Cerebras Code Pro ($50 → ~$660+ equiv at GLM 4.7 rates), NanoGPT $12 (→ $250–780 equiv input), Ollama Max ($100 → $300), Ollama Pro ($20 → $60).
- **Caveat:** flat-plan value collapses for agent workloads that re-send conversation history (NanoGPT counts cached input; Cerebras daily caps throttle bursts).

### Uncertainty register

| Item | Flag |
|---|---|
| OpenRouter BYOK allowance ($25k/mo vs 1M requests/mo) | [UNVERIFIED — conflicting official docs] |
| Cerebras PayGo per-token rates for Qwen 3.8 27B / GPT-OSS 120B | [UNVERIFIED — not in rendered docs] |
| Cerebras GLM 4.7 ~$2.25/$2.75 | [UNVERIFIED — third-party] |
| Tinfoil all rates | [UNVERIFIED — third-party snapshot only] |
| Together Qwen3.8 2.4T cached-input ($0.25 vs $0.50) | [UNVERIFIED — page/catalog disagree] |
| Ollama DeepSeek V4 Pro 0813 $0.66/$1.98 | [UNVERIFIED — possible off-peak rate] |
| NanoGPT output-token metering on subscription | [UNVERIFIED — community conflict] |
| Groq dev-tier rate limits/pricing beyond public catalog | [UNVERIFIED] |
| Nebius current-gen model coverage (V4/K3/GLM-5.x) | catalog still older-gen as of Sept 2026 |
| Vercel GLM 5.3 Flash promo vs Z.AI provider rate | [UNVERIFIED — which applies at checkout] |
| Novita coding plan tier prices | [UNVERIFIED — not on pricing console] |
| Fireworks vs Together "Qwen3.7 Plus" rate discrepancy | [UNVERIFIED — verify model ID] |
| Crusoe Nemotron 3.5 Lightning rate column ordering | [UNVERIFIED] |
