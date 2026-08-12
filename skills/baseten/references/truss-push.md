# `truss push` / `truss watch` for BIS-LLM models

The `truss` CLI builds, deploys, and live-patches Trusses. This file covers only the commands you need to push and iterate on a **BIS-LLM** model (a directory with `config.yaml` containing a `bis_llm:` block — see `bis-llm.md`). For the `truss chains` subcommand group or `truss train`, see the hosted docs; this skill doesn't cover them.

**Prerequisites:** `bis-llm.md` (what's in `config.yaml`); `baseten-cli.md` (the `baseten` CLI does the same push/watch with `--output json` / `--jq` and is preferred for scripted flows).

The published reference is at <https://docs.baseten.co/reference/cli/truss/overview>.

## Install

`uv tool install truss` (or `uvx truss <command>` to run without installing); `pip install truss` also works. `setup.sh` installs it into `~/venv` via `ensure_venv` (see `lib/shared.sh`) — activate with `source ~/venv/bin/activate`.

## Authenticate

```
truss login
```

Paste an API key from <https://app.baseten.co/settings/api_keys> when prompted. Truss stores credentials in `.trussrc` for future commands. In CI, set `BASETEN_API_KEY` and use `--remote <name>` to select the saved remote name. Do not commit `.trussrc`.

## `truss init` - scaffold

```
truss init my-model
```

Creates a starter Truss directory (`config.yaml`, `model/`, `data/`, `packages/`). For a BIS-LLM model, **delete `model/model.py`** and add a `bis_llm:` block to `config.yaml` instead — BIS-LLM is engine-only (no Python in the request path).

## `truss push` - the main flow

`truss push` is the workhorse. Default behavior creates a **published** deployment (immutable snapshot). Use flags to change target, control live reload, wait for completion, and stream logs.

### Common patterns

Iterative dev loop (live-patches code on save):

```
truss push --watch --tail
```

CI-friendly publish that waits and streams logs:

```
truss push --wait --tail
```

CI-friendly publish with machine-readable output:

```
truss push --json --wait
```

Promote straight to production:

```
truss push --promote
```

Promote to a named environment:

```
truss push --environment staging
```

### Key flags

- `--watch`: create a **development** deployment and watch for source changes, applying live patches. The dev model stays warm by default (no scale-to-zero) while watching. **Note:** BIS-LLM itself doesn't support scale-to-zero (`min_replica` >= 1), so this mainly affects whether the watcher pings keep the dev slot active.
- `--watch-hot-reload`: with `--watch`, swap the model class in-process instead of restarting the server. Faster iteration; preserves loaded weights and caches; does **not** re-run `__init__` or `load`. Only valid when only `predict()` changed (rarely relevant for BIS-LLM engine-only deploys, where there's no `model.py`).
- `--promote`: published deployment, promoted to production even if a production deployment already exists.
- `--environment <name>`: published deployment, promoted into the named environment. When set, `--promote` is ignored.
- `--preserve-previous-production-deployment`: with `--promote`, inherit the previous production deployment's autoscaling settings.
- `--preserve-env-instance-type` / `--no-preserve-env-instance-type`: with `--environment`, keep the environment's configured instance type instead of the Truss config's `resources`. Default is to preserve.
- `--deployment-name <name>`: name the published deployment (alphanumeric, `.`, `-`, `_`). Ignored for `--watch`.
- `--model-name <name>`: temporarily override `model_name` without editing `config.yaml`.
- `--wait` / `--no-wait`: block until the deploy finishes; exit non-zero on failure.
- `--tail`: stream deployment logs after push. Combines with `--wait` and with `--watch`.
- `--json`: emit structured output suitable for CI parsing.
- `--labels '{"k":"v"}'`: attach searchable key/value labels to the deployment.
- `--include-git-info`: attach git sha, branch, and tag.
- `--no-cache`: force a full rebuild without using cached layers.
- `--timeout-seconds <n>`: client-side polling timeout when `--wait`-ing.
- `--deploy-timeout-minutes <n>`: server-side deploy timeout.
- `--remote <name>`: pick a remote from `.trussrc`. Useful in CI with multiple workspaces.
- `--config <path>`: use a non-default config file.
- `--team <name>`: deploy to a specific team (organizations with teams enabled).

## `truss watch` - re-attach to a dev deployment

```
truss watch
```

Re-attaches to an existing development deployment and applies live patches when files change. Equivalent to running `truss push --watch` once and resuming the watch loop later.

`truss watch` keeps the dev deployment **warm** (prevents scale-to-zero) while it is running. If the user expects the dev deployment to scale to zero while a watch is active, surface this so they understand why replicas are still running.

Other flags:

- `--hot-reload`: in-process model swap, same semantics as `--watch-hot-reload` on push.
- `--no-keepalive`: let the dev deployment scale to zero while watching (it won't, for BIS-LLM, since `min_replica` >= 1 — but the flag still suppresses the periodic pings).
- `--remote`, `--config`, `--team`, `--model-name`: same meanings as on `push`.

## `truss model-logs` - fetch deployment logs

```
truss model-logs <model-id>
```

Fetches recent logs for a deployment. For continuous streaming during a push, prefer `truss push --tail`. For richer log querying (time windows, `--since`, `--tail`, `--min-level`, `--includes`, `--excludes`, `--request-id`, `--replica`, JSONL streaming), use `baseten model deployment logs` (see `baseten-cli.md`).

## `truss container` / `truss image` - local debugging

`truss container` builds and runs the Truss as a Docker container locally — useful to reproduce build failures. `truss image build` produces the Docker image without deploying. Rarely needed for BIS-LLM (config-only, no `model.py` to debug locally).

## `truss configure`, `truss whoami`, `truss cleanup`

Workspace and account utilities. `whoami` prints the current authenticated user. `configure` manages remotes in `.trussrc`. `cleanup` removes locally cached deployment artifacts.

## Iterating on a BIS-LLM deployment

Agent-flavored notes for post-first-deploy iteration. Conceptual model and feature reference live in the docs — this section covers the agent-specific watcher recipe and exact log markers.

Docs: <https://docs.baseten.co/development/model/deploy-and-iterate>.

### Three cost tiers — pick the cheapest valid one

| Tier | What runs | Wall time | Triggered by |
| --- | --- | --- | --- |
| **Image rebuild** | Docker build + push + deploy + `load()` | minutes (3-10) | a small set of unpatchable config keys: `python_version`, `resources` (compute/instance type), `live_reload`. The watcher detects and refuses these — see "When to drop the watcher" below. |
| **Live patch + reload** | File sync, server restart, `load()` re-runs | seconds (10-60) | everything else: `config.yaml` edits (engine settings, autoscaling targets, advanced features), `requirements`, `system_packages`, env vars, `external_data`, `model_metadata`, `build_commands`, data dir, bundled packages |
| **Hot-reload** | In-process class swap; `__init__` / `load` do **not** re-run | sub-second to ~2s | `predict()`-only changes. **Not applicable to BIS-LLM engine-only deploys** (no `model.py`). |

For BIS-LLM, most iteration is **tier 1 or tier 2**: editing `bis_llm.config.engine_config` (e.g. `max_num_seqs`, `gpu_memory_utilization`) is a tier-2 live patch; changing `resources.accelerator` is a tier-1 rebuild.

### Watcher recipe for agents

`--watch` was built for humans saving files in an IDE. An agent edits in discrete bursts and knows when it is ready to test. Truss has no one-shot `truss patch` verb — patches only happen as a side effect of `truss push --watch`. The robust pattern for an agent is **one watcher per edit**: start the watcher, wait for the patch marker, kill it, test. Each cycle is self-contained, no long-lived background process for the harness to lose track of, recovery from any mid-loop failure is trivial (re-edit, re-run).

`--watch` always produces a **development deployment** — mutable, single replica (BIS-LLM: `min_replica` >= 1, so it won't scale to zero), no autoscaling, one per model. Live patching is only possible against this slot, never against a published deployment.

Per edit (adapt to your harness — Bash, Python job control, etc.):

```bash
# 1. Edit config.yaml (atomic write — most editor/agent tools already do this).

# 2. Start the watcher in the background, fresh log per cycle.
truss push --watch --remote <name> > /tmp/watch.log 2>&1 &
WATCH_PID=$!

# 3. Wait for a terminal patch marker (see "Log markers" below). Includes the
#    "Nothing to do" no-op so a config that diffs clean still terminates the
#    loop. Hard timeout prevents infinite hang if the watcher silently stalls.
deadline=$((SECONDS + 300))
while [ $SECONDS -lt $deadline ]; do
  grep -qE \
    'Model <name> patched successfully|Failed to patch|Patch failed' \
    /tmp/watch.log && break
  sleep 2
done

# 4. Kill the watcher; the next edit gets a fresh one.
kill "$WATCH_PID" 2>/dev/null

# 5. Test the dev endpoint with a foreground call. On failure, fetch deployment
#    logs via `baseten model deployment logs` — don't guess.
```

The watcher's ~5-15s of startup per cycle is in the noise next to the tier-2 patch wait (10-60s) and the test call. Trading that for the robustness of stateless cycles is worth it.

### Log markers (from truss source)

| Surface | Success | No-op | Failure | Cycle done |
| --- | --- | --- | --- | --- |
| Truss | `Model <name> patched successfully.` | (silent skip) | `Failed to patch. ...` / `Patch failed: ...` | (rely on success/failure line) |

### When to drop the watcher

The watcher cannot rebuild the image. If your change touches one of the unpatchable keys (`python_version`, `resources`, `live_reload`), or if the log shows `Patching is not supported for: <key>` / `Failed to calculate patch. Change type might not be supported.`: do a one-shot plain `truss push` (no `--watch`, exits when upload completes), poll deployment status until `ACTIVE` (via `baseten model deployment describe`), then resume the one-shot watcher recipe. Don't enumerate every "is this patchable?" up front — try the patch, fall back on the warning.

For BIS-LLM, **changing `resources.accelerator` (e.g. H100 → H200, or `:1` → `:4`) always requires a rebuild** — drop the watcher and do a plain `truss push`.

### Publish step

After iteration: do one clean `truss push` without `--watch` so production starts from a fresh image, not a patched-on-top-of-patched dev state. Then promote to the target environment:

```bash
truss push --wait
baseten model deployment promote --model-id <mid> --deployment-id <did> --yes
```

## Inference SSH

Full terminal in a running model container — debug, inspect files, run commands, `scp`/`sftp`. Requires org enablement (contact support) and `runtime.remote_ssh.enabled: true` in `config.yaml`. Docs: <https://docs.baseten.co/observability/inference-ssh>. The `baseten ssh` CLI group sets this up (see `baseten-cli.md`).

## Gotchas

- **Default `truss push` is a published deployment, not a dev one.** For an iterative dev loop, use `--watch` (or `truss watch` afterwards).
- **`truss watch` keeps the dev deployment warm by default.** Replicas do not scale to zero while the watch is running. (For BIS-LLM, `min_replica` >= 1 anyway, so this is about whether the watcher pings.)
- **`--watch-hot-reload` does not re-run `__init__` or `load`.** Not applicable to BIS-LLM engine-only deploys (no `model.py`).
- **`.trussrc` holds credentials.** Do not commit it. In CI / scripted flows, prefer `BASETEN_API_KEY` plus `--remote <name>` over committing `.trussrc`. Truss is moving toward OS keyring storage; if asking for a key, ask the user to export it as an env var rather than reading or writing credential files yourself.
- **BIS-LLM `resources.accelerator` changes require a rebuild.** Drop the watcher and do a plain `truss push`.
- **Prefer `baseten model push` for scripted flows** — it supports `--output json` / `--jq` for machine-readable output; `truss push --json` exists but the `baseten` CLI's filtering is richer.

## Further reading

- CLI overview: <https://docs.baseten.co/reference/cli/truss/overview>
- `truss push` reference: <https://docs.baseten.co/reference/cli/truss/push>
- `truss watch` reference: <https://docs.baseten.co/reference/cli/truss/watch>
- Deploy and iterate guide: <https://docs.baseten.co/development/model/deploy-and-iterate>
- Calling deployed models: see `baseten-cli.md` (`baseten model predict`).
