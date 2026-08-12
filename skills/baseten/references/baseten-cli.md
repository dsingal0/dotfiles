# `baseten` CLI for BIS-LLM workflows

The `baseten` CLI manages your Baseten workspace from the command line: models, deployments, environments, secrets, API keys, and raw API access. Every Baseten-native command supports `--output json` and `--jq` filtering, so anything you do interactively is scriptable. **This is the preferred CLI for scripted/agent flows** — richer filtering than `truss push --json`.

The CLI is open source at <https://github.com/basetenlabs/baseten-cli>. Published reference: <https://docs.baseten.co/reference/cli/baseten/overview>.

> The CLI is in **beta** — commands, flags, output schemas, and the install path may change before GA. ⚠️ Verify with `--help` if a flag behaves unexpectedly.

This file covers only the commands relevant to **BIS-LLM** workflows (push, watch, predict, deployment logs/metrics/promote/describe/list). For the full command tree, run `baseten --help`.

## Install

```sh
brew tap basetenlabs/baseten
brew trust basetenlabs/baseten   # optional, limits tap code evaluation
brew install baseten
```

Upgrade with `brew update && brew upgrade baseten`. On other platforms, download from <https://github.com/basetenlabs/baseten-cli/releases/latest>, extract, and place `baseten` on your PATH. `setup.sh` installs this via `install_baseten_cli` (see `lib/shared.sh`).

Verify: `baseten version`.

## Authenticate

```sh
baseten auth login --web      # interactive, browser-based
# or, for CI / headless:
export BASETEN_API_KEY=...     # create at https://app.baseten.co/settings/api_keys
```

The CLI never prompts when stdin isn't a terminal, so it's safe to run headless. See `baseten auth --help` for browser login, reading a key from stdin, switching accounts, and credential storage.

## Output and filtering

Every Baseten-native command supports four output formats through `--output`:

- `text` (default): human-readable narrative.
- `json`: a single JSON document. Pair with `--jq EXPR` to extract one field.
- `jsonl`: one JSON record per line. Used by commands that stream results (e.g. `logs --tail`).
- `none`: suppress stdout entirely.

```sh
baseten model push --jq '.predict_url'
baseten model list --jq '.models[].id'
baseten model deployment logs --model-id <mid> --deployment-id <did> --output jsonl --jq '.message'
```

`--jq` implies `--output json` (or `jsonl` for streamed commands), so a single flag turns any command into a clean value for the next stage of a pipeline.

## Global flags

| Flag | Description |
| --- | --- |
| `--profile` | Use a specific stored profile, overriding `BASETEN_PROFILE` and the current profile. |
| `--output`, `-o` | Output format: `text`, `json`, `jsonl`, or `none`. |
| `--jq`, `-q` | Filter JSON output with a jq expression; implies `--output json` (or `jsonl`). |
| `--verbose`, `-v` | Enable verbose logging. |

## `baseten model push` - deploy a BIS-LLM model

```sh
baseten model push [OPTIONS] [--dir DIR]
```

Build a model archive, upload it to Baseten, and create either a new model or a new deployment of an existing model. The current directory is used by default; pass `--dir` to push a model directory at another path. The model is identified by the `model_name` field in `config.yaml`; use `--override-name` to override that for this push only.

### Key flags

- `--deploy-timeout <dur>`: deployment timeout as a Go duration (e.g. `30m`, `1h`); range 10m–24h.
- `--deployment-name <name>`: human-readable name for the new deployment.
- `--develop`: push as a **development deployment** (the model's single mutable dev slot, created if absent, overwritten in place). Incompatible with `--environment` and `--deployment-name`.
- `--dir <path>` (default `.`): model directory to push.
- `--dry-run`: validate the push and request upload credentials without uploading or creating anything.
- `--environment <name>`: stable environment to push to.
- `--labels '<json>'`: user-provided labels for the deployment as a JSON object, e.g. `'{"team":"ml","priority":1}'`.
- `--no-build-cache`: force a full rebuild without using cached layers.
- `--override-env-instance-type`: use this deployment's instance type instead of preserving the target environment's. Only meaningful when an environment is targeted.
- `--override-name <name>`: override `model_name` from `config.yaml` for this push only (does not modify the on-disk file).
- `--tail`: stream build and runtime logs to stderr after pushing. Logs are always text-formatted; use `baseten model deployment logs --tail` for structured log streaming.
- `--team <name>`: team the model belongs to (only valid for new models).
- `--wait`: block until the deployment is active. Exits non-zero on a terminal-failure status.
- `--watch`: after pushing, watch the model directory and live-patch the development deployment on change. **Implies `--develop`.**
- `--watch-hot-reload`: with `--watch`, hot-reload the running container when every change is to model code; mixed changes fall back to a cold patch. **Not applicable to BIS-LLM engine-only deploys** (no `model.py`).
- `--watch-no-keepalive`: with `--watch`, let the development deployment scale to zero while watching. By default it is kept warm by periodic pings. (BIS-LLM: `min_replica` >= 1, so it won't scale to zero anyway — but the flag suppresses the pings.)

### Examples

Push the current directory as a new deployment, wait, and stream logs:

```sh
baseten model push --tail --wait
```

Print the new deployment's predict URL (machine-readable):

```sh
baseten model push --jq '.predict_url'
```

Iterative dev loop (live-patches on save):

```sh
baseten model push --watch --tail
```

## `baseten model watch` - re-attach to a dev deployment

```sh
baseten model watch [OPTIONS] [--dir DIR]
```

Watch a model directory and patch the model's development deployment in place on every change, skipping a full rebuild. The model must already have a development deployment; if not, run `baseten model push --develop` (or `baseten model push --watch`) first. Runs until interrupted.

Some changes cannot be expressed as a patch (removing `config.yaml`, or any change under the data directory); the watcher reports these and you must re-push.

### Flags

- `--dir <path>` (default `.`): model directory to watch.
- `--hot-reload`: hot-reload the running container when every change is to model code; mixed changes fall back to a cold patch. **Not applicable to BIS-LLM engine-only deploys.**
- `--no-keepalive`: let the development deployment scale to zero while watching. By default it is kept warm by periodic pings.
- `--team <name>`: team the model belongs to; disambiguate when the same `model_name` exists in multiple teams.

## `baseten model predict` - call a BIS-LLM model

```sh
baseten model predict [OPTIONS]
```

POST a JSON request to a model and write the response to stdout. Targets the **production** environment by default. Use `--environment`, `--deployment-id`, `--deployment-name`, or `--regional` to target something else.

Streaming responses (Transfer-Encoding: chunked) are passed through as they arrive. For machine-readable streaming JSON from OpenAI-compatible BIS-LLM models, use `--output jsonl`.

### Flags

- `--data '<json>'`: inline JSON request body. Mutually exclusive with `--file`.
- `--file <path>`: path to a JSON file containing the request body. Use `-` for stdin.
- `--deployment-id <id>`: specific deployment to target. Mutually exclusive with `--environment`, `--deployment-name`, `--regional`.
- `--deployment-name <name>`: name of the deployment to target.
- `--environment <name>`: environment to target (e.g. `production`, `development`). Defaults to `production`.
- `--model-id <id>` / `--model-name <name>`: identify the model (use `--team` to disambiguate by name).
- `--regional <name>`: regional environment name; routes through the regional hostname.
- `--websocket`: use the WebSocket predict endpoint. Sends the body as one frame, reads one frame back, then closes. Not for multi-message or back-and-forth sessions.

### Examples

Send an inline OpenAI-style chat request:

```sh
baseten model predict --model-id <mid> --data '{"messages":[{"role":"user","content":"hello"}]}'
```

Send a request body from a file:

```sh
baseten model predict --model-id <mid> --file request.json
```

Extract a field when the model returns JSON:

```sh
baseten model predict --model-id <mid> --data '{"x":1}' --jq '.result'
```

## `baseten model deployment logs` - fetch deployment logs

```sh
baseten model deployment logs [OPTIONS]
```

By default returns up to `--limit` lines from the last 30 minutes, newest first, and prints a note to stderr when `--limit` trims older lines. Use `--start`/`--end` or `--since` to scope the window (max 7 days). Use `--tail` to stream live logs until the deployment leaves a runnable state or you interrupt with Ctrl-C.

For machine-readable streaming, prefer `--output jsonl` over `--output json`.

### Flags

- `--deployment-id <id>` / `--deployment-name <name>`: identify the deployment.
- `--model-id <id>` / `--model-name <name>`: identify the model (use `--team` to disambiguate by name).
- `--start <iso8601>` / `--end <iso8601>`: time range. Values without a timezone designator are interpreted as local time. Default end is now; default start is 30 min before end. Window must be at most 7 days.
- `--since <dur>`: shortcut for a window from a relative time ago until now. Accepts a Go duration (e.g. `30m`, `1h30m`) or `Nd` (e.g. `3d`). Max `7d`. Mutually exclusive with `--start`/`--end`.
- `--limit <int>` (default 5000): max lines to return, paging backward from the end. Use `0` for no limit. Not applicable with `--tail`.
- `--tail`: stream new logs as they arrive until the deployment leaves a runnable state or you interrupt. Cannot be combined with time-range or filter flags.
- `--min-level <level>`: `debug`, `info`, `warning`, or `error`. Only return logs at or above this severity.
- `--includes <substr>` (repeatable): case-sensitive substring that must appear in the log message. All repeated values must match.
- `--excludes <substr>` (repeatable): case-sensitive substring; lines containing it are dropped.
- `--search-pattern <re2>`: RE2 regex matched against the log message. Prefer `--includes`/`--excludes` for plain substring matches.
- `--replica <short-id>`: only return logs emitted by this replica (5-char short ID).
- `--request-id <id>`: only return logs tagged with this inference request ID.

### Examples

Print logs for a deployment over the last hour:

```sh
baseten model deployment logs --model-id <mid> --deployment-id <did> --since 1h
```

Tail live logs:

```sh
baseten model deployment logs --model-id <mid> --deployment-id <did> --tail
```

Filter to warnings and above that contain a term:

```sh
baseten model deployment logs --model-id <mid> --deployment-id <did> --min-level warning --includes timeout
```

Stream just the log messages as JSONL:

```sh
baseten model deployment logs --model-id <mid> --deployment-id <did> --output jsonl --jq '.message'
```

## `baseten model deployment metrics` - fetch deployment metrics

```sh
baseten model deployment metrics [OPTIONS]
```

Fetch metrics for a model deployment. Use `--mode current` for a snapshot, `--mode summary` to aggregate a window, or `--mode series` to plot values over time. Scope the window with `--since` or `--start`/`--end` (max 7 days; only applies to summary and series), and select metrics with one or more `--metric` flags.

For BIS-LLM, the metrics that matter are listed in `bis-llm.md` (engine-level, autoscaler, router/KV cache). Pass them explicitly with `--metric`.

### Flags

- `--mode <mode>` (default `current`): `current` (instantaneous snapshot at now), `summary` (aggregate the whole window into one value per metric), `series` (evenly-spaced points across the window). `--start`/`--end`/`--since` are only meaningful for summary and series.
- `--metric <name>` (repeatable): metric name to return; see <https://docs.baseten.co/observability/export-metrics/supported-metrics> for the available names. May be repeated. When omitted, a default set is returned.
- `--start <iso8601>` / `--end <iso8601>`: time range. If omitted, server defaults start to 1 hour before end. Window must be at most 7 days.
- `--since <dur>`: shortcut for a window from a relative time ago until now. Go duration or `Nd`. Max `7d`. Mutually exclusive with `--start`/`--end`.
- `--no-chart`: for `--mode series`, emit a per-step table instead of sparklines.

### Examples

Show a current snapshot of the default metrics:

```sh
baseten model deployment metrics --model-name <mname> --deployment-id <did>
```

Summarize request volume and latency over the last hour:

```sh
baseten model deployment metrics --model-id <mid> --deployment-id <did> \
  --mode summary --since 1h \
  --metric baseten_inference_requests_total \
  --metric baseten_end_to_end_response_time_seconds
```

Plot a series over the last 6 hours:

```sh
baseten model deployment metrics --model-id <mid> --deployment-id <did> --mode series --since 6h
```

BIS-LLM-specific: watch in-flight tokens and TPS over the last hour:

```sh
baseten model deployment metrics --model-id <mid> --deployment-id <did> \
  --mode series --since 1h \
  --metric autoscaler_in_flight_tokens \
  --metric tps_per_request \
  --metric concurrent_requests
```

Print the metric names returned:

```sh
baseten model deployment metrics --model-id <mid> --deployment-id <did> --jq '.metric_descriptors[].name'
```

## `baseten model deployment promote` - promote to an environment

```sh
baseten model deployment promote [OPTIONS]
```

Promote a model deployment to an environment. Defaults to `production`. Cleanup of the previous deployment is controlled by the target environment's promotion cleanup strategy.

Prompts for yes/no confirmation. Pass `--yes` to skip the prompt. **When stdin is not a terminal, `--yes` is required.**

### Flags

- `--deployment-id <id>` / `--deployment-name <name>`: identify the deployment.
- `--model-id <id>` / `--model-name <name>`: identify the model (use `--team` to disambiguate by name).
- `--environment <name>` (default `production`): target environment name.
- `--override-env-instance-type`: use this deployment's instance type instead of preserving the target environment's.
- `--yes`: skip the interactive confirmation prompt. **Required when stdin is not a terminal.**

### Examples

Promote to production without the confirmation prompt:

```sh
baseten model deployment promote --model-id <mid> --deployment-id <did> --yes
```

Promote to a non-production environment using the deployment's own instance type:

```sh
baseten model deployment promote --model-id <mid> --deployment-id <did> \
  --environment staging --override-env-instance-type --yes
```

Print the promoted deployment's status:

```sh
baseten model deployment promote --model-id <mid> --deployment-id <did> --yes --jq '.status'
```

## `baseten model deployment describe` / `list` / `config`

### describe

```sh
baseten model deployment describe --model-id <mid> --deployment-id <did>
```

Field-per-line summary in text mode: ID, Name, Model, Environment (optional), Status, Instance (optional), Replicas, Created. JSON mode returns the full `managementapi.Deployment`.

Print just the deployment status:

```sh
baseten model deployment describe --model-id <mid> --deployment-id <did> --jq '.status'
```

### list

```sh
baseten model deployment list --model-id <mid>
```

Table with columns: ID, NAME, ENVIRONMENT, STATUS, INSTANCE, REPLICAS, CREATED. When no deployments exist, prints "No deployments found." to stderr.

Print just the deployment IDs:

```sh
baseten model deployment list --model-id <mid> --jq '.deployments[].id'
```

### config

```sh
baseten model deployment config --model-id <mid> --deployment-id <did>
```

Prints the original `config.yaml` (preserving comments and ordering) when available, otherwise the parsed config marshaled as YAML. Use `--output json` to emit the full `{config, raw_config}` envelope.

Extract the parsed `model_name`:

```sh
baseten model deployment config --model-id <mid> --deployment-id <did> --jq '.config.model_name'
```

## `baseten model deployment activate` / `deactivate` / `delete`

- `activate --model-id <mid> --deployment-id <did>`: activate a model deployment.
- `deactivate --model-id <mid> --deployment-id <did> --yes`: deactivate. Prompts for yes/no; pass `--yes` to skip. **`--yes` is required when stdin is not a terminal.**
- `delete --model-id <mid> --deployment-id <did> --yes`: delete a single deployment. Deployments associated with an environment (production, development) and the only deployment of a model **cannot be deleted server-side**. Prompts for yes/no; `--yes` required when stdin is not a terminal.

## `baseten model list` / `describe`

- `list`: list Baseten models. Table columns: ID, NAME, TEAM, DEPLOYMENTS, CREATED. Scope to a team with `--team <name>`. Print just IDs: `baseten model list --jq '.models[].id'`.
- `describe --model-id <id>` / `--model-name <name>`: field-per-line summary (ID, Name, Team, Deployments, Instance, Production, Development, Created). Print the production deployment ID: `baseten model describe --model-id <mid> --jq '.production_deployment_id'`.

## `baseten model deployment download` - fetch the Truss source

```sh
baseten model deployment download --model-id <mid> --deployment-id <did> --out-dir ./truss
# or save as a tar:
baseten model deployment download --model-id <mid> --deployment-id <did> --out-file truss.tar
```

Exactly one of `--out-file` (raw tar bytes) or `--out-dir` (extract the tar) is required. Use `--overwrite` to replace an existing file or write into a non-empty directory. Useful for pulling a deployed BIS-LLM config back to disk for editing.

## Other command groups (not BIS-LLM-specific, but available)

- `baseten api`: make raw management or inference API requests.
- `baseten auth`: log in, log out, switch accounts, inspect the active account.
- `baseten model environment`: activate, deactivate, describe, list, stream logs from, and fetch metrics for model environments.
- `baseten model deployment replica`: terminate an individual deployment replica.
- `baseten model-api`: list and inspect Baseten Model APIs (hosted).
- `baseten org api-key` / `org billing` / `org secret` / `org team` / `org user`: org-level management.
- `baseten ssh`: set up SSH access to running Baseten workloads (requires org enablement; see `truss-push.md` § Inference SSH).
- `baseten truss <args>`: forward commands to the `truss` binary on your PATH.
- `baseten version` / `whoami`: version info / authenticated user.

Run `baseten <command> --help` for any of these.

## Gotchas

- **`--yes` is required when stdin is not a terminal** for `deactivate`, `delete`, `promote`, and `model delete`. The CLI never prompts headless; it errors instead.
- **`--jq` implies `--output json` (or `jsonl` for streamed commands).** You don't need to pass both.
- **Log windows are bounded.** Default tail is the last 30 min, max 7 days. A problem reported 5 min ago may have aged out of the default tail — use `--since` or `--start`/`--end`.
- **`--tail` cannot be combined with time-range or filter flags** on `logs`. Use one or the other.
- **`baseten model push` default is a published deployment, not a dev one.** For an iterative dev loop, use `--watch` (or `baseten model watch` afterwards). `--watch` implies `--develop`.
- **`--watch-hot-reload` is not applicable to BIS-LLM engine-only deploys** (no `model.py`).
- **BIS-LLM `resources.accelerator` changes require a rebuild** — the watcher cannot patch them; do a plain `baseten model push` (no `--watch`).
- **`baseten truss <args>` forwards to the `truss` binary on your PATH.** Use this when you want to stay under one CLI but reach truss-only subcommands.

## Further reading

- CLI overview: <https://docs.baseten.co/reference/cli/baseten/overview>
- `baseten model`: <https://docs.baseten.co/reference/cli/baseten/model>
- `baseten model deployment`: <https://docs.baseten.co/reference/cli/baseten/model-deployment>
- CLI repo: <https://github.com/basetenlabs/baseten-cli>
- Manage deployments guide: <https://docs.baseten.co/deployment/manage/overview>
- Logs: <https://docs.baseten.co/observability/logs>
- Supported metrics: <https://docs.baseten.co/observability/export-metrics/supported-metrics>
- BIS-LLM metrics to watch: see `bis-llm.md` § Observability.
