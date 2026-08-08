---
name: validate-model-endpoint-readiness
description: Validate functional readiness before deploying a model endpoint. Use to prove advertised features, full context, default output of at least 16K tokens, and complete smoke compatibility.
---

# Validate Model Endpoint Readiness

Produce an evidence-backed `READY`, `NOT READY`, or `BLOCKED` verdict before an
endpoint is deployed or exposed to users. Treat model capability,
endpoint behavior, and gateway behavior as separate claims.

## Resources

| Resource | Purpose |
|---|---|
| `scripts/probe_token_limits.py` | Prove a prepared near-limit context request and an observed 16K-or-longer completion. |
| `assets/readiness-report.md.tmpl` | Record sources, test scope, evidence, failures, and the final verdict. |
| A complete endpoint smoke-test harness | Run the canonical compatibility suite used by your deployment workflow. |

## Rules

- Run this workflow before deployment configuration, catalog publication, or
  production promotion. Do not mutate deployment or gateway configuration.
- Research can begin immediately. Do not send live inference traffic until the
  user approves the endpoint, model alias, credential, test scope, and the cost
  of the full-context and 16K-output probes.
- Prefer the model publisher's model card, configuration, tokenizer, and API
  documentation. Record exact URLs and retrieval dates. Use provider docs only
  for provider-specific endpoint behavior.
- Never accept a model-card capability as proof that the endpoint exposes it.
- Never accept `/v1/models`, health, a successful short completion, or an
  accepted `max_tokens` value as boundary proof. The default-output probe must
  omit all client-supplied output-limit fields.
- Never print credentials or generated 16K-token content. Keep only token
  counts, timings, finish reasons, response IDs, concise errors, and hashes or
  paths for reviewed artifacts.

## 1. Freeze the target

Record the exact endpoint base URL, model alias, provider, API protocol,
credential source name, and whether the target is staging or production.
Resolve redirects and gateway rewrites before testing. Stop if the final target
is ambiguous. Production traffic requires explicit current-turn approval.

Copy `assets/readiness-report.md.tmpl` to an artifact directory outside a
repository. Do not commit generated prompts, responses, or credentials.

## 2. Build the functional contract

Read the official model card and API documentation and turn every prominently
advertised serving feature into a row in the report. At minimum, inspect:

- input modalities: text, image, video, audio, or document;
- context window and whether it is shared between input and output;
- maximum output length;
- streaming and non-streaming behavior;
- tool/function calling, parallel tools, structured/JSON output, reasoning
  controls, and multi-turn behavior when advertised;
- the model's actual task type, such as generation, embedding, reranking, ASR,
  TTS, or translation.

For each row, record the authoritative claim, endpoint request shape, observable
pass condition, and whether the feature is `REQUIRED` or `NOT APPLICABLE`.
Absence from generic OpenAI compatibility is not evidence that an advertised
feature is optional. If documentation conflicts, use the narrower endpoint
limit and mark the conflict as a blocker until resolved.

Review this matrix and the estimated token traffic with the user before any
live request. A 16K output probe consumes at least 16,384 generated tokens; a
full-context probe may consume the entire advertised input window.

## 3. Exercise every advertised feature

Send the smallest deterministic request that proves each required feature
through the exact endpoint and model alias under review. Validate response
semantics, not only HTTP status. For multimodal models, use each advertised
modality; a passing image request does not prove video or audio support.

Record request and response metadata without secret headers or large content.
Classify failures by layer: authentication/access, gateway normalization,
provider contract, endpoint configuration, or model behavior. Authentication
and budget failures are `BLOCKED`, not model failures, but they still prevent a
`READY` verdict.

## 4. Prove token limits

Use the official tokenizer and chat template for the exact model revision to
prepare a non-sensitive prompt whose complete templated input is within the
script's tolerance of:

```text
advertised_context_window - context_response_tokens
```

Record that independently computed templated-token count. Do not estimate from
characters or words. Then run both probes:

```bash
SKILL_DIR="$(cd "$(dirname "<path-to-this-SKILL.md>")" && pwd)"

python3 "$SKILL_DIR/scripts/probe_token_limits.py" \
  --base-url "$OPENAI_BASE_URL" \
  --model "$OPENAI_MODEL" \
  --context-window <advertised-context-tokens> \
  --context-prompt-file <prepared-prompt.txt> \
  --expected-context-input-tokens <official-tokenizer-count> \
  --evidence-json <artifact-dir>/token-limits.json \
  --allow-live-traffic
```

The script defaults to a 32-token context response, a 64-token boundary
tolerance, and a minimum observed completion of 16,384 tokens. The output
request deliberately omits `max_tokens`, `max_completion_tokens`,
`max_output_tokens`, and equivalent fields so it proves the endpoint does not
clip output below 16K by default. Tighten the context tolerance when the
tokenizer and live usage accounting agree. If the endpoint uses the Responses
API instead of Chat Completions, reproduce the same two probes with its native
request shape while still omitting its output-limit field, and record
equivalent `input_tokens` and `output_tokens` evidence.

Pass the context gate only when the near-boundary request succeeds and live
usage confirms the required input size. Pass the output gate only when one
uncapped-by-the-client response actually reports at least 16,384
output/completion tokens. A default `length` stop below 16K is a hard failure.
An earlier voluntary stop is inconclusive and remains `BLOCKED`; retry with a
better long-output prompt, but never add an output-limit field. Authoritative
parsed runtime configuration may supplement a live result but must not replace
it.

## 5. Run the complete smoke suite

Use the complete smoke-test harness for the deployment workflow; do not
substitute a one-request health probe or a shallow fleet sweep.

```bash
OPENAI_BASE_URL="$OPENAI_BASE_URL" \
OPENAI_MODEL="$OPENAI_MODEL" \
OPENAI_API_KEY="$OPENAI_API_KEY" \
uv run <path-to-canonical-smoke-test.py>
```

Run the default suite with no `--cases` reduction. Then run every applicable
opt-in group, including `multimodal` for vision endpoints and `messages` when
the endpoint exposes the Anthropic Messages API. Run mode-specific embedding,
reranking, audio, or other tests required by the contract. Concurrency is a
load/capacity test and is outside this functional gate unless explicitly added
to the reviewed contract.

Every applicable case must pass. Record the harness revision, exact cases,
pass count, and each named failure. A justified `NOT APPLICABLE` is allowed; a
skip caused by missing credentials, missing tooling, timeout, or unsupported
advertised behavior is `BLOCKED` or `FAILED`.

## 6. Decide readiness

Use only these verdicts:

- `READY`: every advertised functional requirement passes, the full advertised
  context boundary passes, observed output is at least 16,384 tokens, and every
  applicable smoke case passes.
- `NOT READY`: at least one executed hard gate fails.
- `BLOCKED`: required evidence could not be collected. Never convert `BLOCKED`
  or `UNVERIFIED` evidence into `READY`.

Name the exact blockers and the owning layer. Include artifact paths and source
URLs, but do not publish, deploy, open tickets, or change configuration unless
the user separately requests that action.
