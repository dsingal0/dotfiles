# factory.sh - Factory (droid CLI) BYOK custom models + auth shared by every
# bootstrap script.
#
# Sourced by lib/shared.sh; not executable on its own.

# Write Baseten BYOK custom models into ~/.factory/settings.json.
#
# Reads BASETEN_API_KEY from the environment (callers source .env first).
# Skips with a warning if unset. Idempotent: existing entries for the same
# model id are updated in place (api key refresh); new ones are appended;
# Baseten entries whose model is no longer served are pruned.
#
# The model list is synced with Baseten Model APIs; the live source of truth is
# `curl https://inference.baseten.co/v1/models -H "Authorization: Bearer $BASETEN_API_KEY"`.
configure_factory_models() {
  if [[ -z "${BASETEN_API_KEY:-}" ]]; then
    echo "WARNING: BASETEN_API_KEY is not set. Skipping Baseten model config."
    echo "         To enable: cp .env.example .env and fill in your key, or export BASETEN_API_KEY."
    return 0
  fi

  mkdir -p ~/.factory
  BASETEN_API_KEY="$BASETEN_API_KEY" python3 - << 'PYEOF'
import json, os

settings_path = os.path.expanduser("~/.factory/settings.json")
try:
    with open(settings_path, "r") as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

settings.setdefault("customModels", [])

api_key = os.environ["BASETEN_API_KEY"]
BASE_URL = "https://inference.baseten.co/v1"

# Per-model reasoning_effort values, biased toward "high" (never xhigh/max),
# validated against each model's supported set (docs.baseten.co/inference/
# model-apis/reasoning).
REASONING_EFFORT_SUPPORTED = {
    "deepseek-ai/DeepSeek-V4-Pro-0813": {"none", "minimal", "low", "medium", "high", "xhigh", "max"},
    "zai-org/GLM-5.3": {"none", "high", "max"},
    "zai-org/GLM-5.3-Flash": {"none", "high", "max"},
    "zai-org/GLM-5.2": {"none", "high", "max"},
    "zai-org/GLM-5.2-Fast": {"none", "high", "max"},
}
REASONING_EFFORT_VALUE = {
    "deepseek-ai/DeepSeek-V4-Pro-0813": "high",
    "zai-org/GLM-5.3": "high",
    "zai-org/GLM-5.3-Flash": "high",
    "zai-org/GLM-5.2": "high",
    "zai-org/GLM-5.2-Fast": "high",
}
# Opt-in thinking models that need chat_template_args.enable_thinking to reason.
ENABLE_THINKING = {
    "nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B", "zai-org/GLM-5.2", "zai-org/GLM-5.2-Fast",
}

def baseten_model(model, display_name, no_image, max_output):
    extra_args = {}
    if model in REASONING_EFFORT_VALUE:
        value = REASONING_EFFORT_VALUE[model]
        supported = REASONING_EFFORT_SUPPORTED[model]
        if value not in supported:
            raise ValueError(
                "reasoning_effort %r not supported for %s (supported: %s)"
                % (value, model, sorted(supported)))
        extra_args["reasoning_effort"] = value
    if model in ENABLE_THINKING:
        extra_args["chat_template_args"] = {"enable_thinking": True}
    entry = {
        "model": model,
        "displayName": display_name,
        "baseUrl": BASE_URL,
        "apiKey": api_key,
        "provider": "generic-chat-completion-api",
        "maxOutputTokens": max_output,
        "noImageSupport": no_image,
    }
    if extra_args:
        entry["extraArgs"] = extra_args
    return entry

# Per-model max output mirrors /v1/models max_completion_tokens.
baseten_models = [
    baseten_model("zai-org/GLM-5.3", "GLM 5.3 [Baseten]", True, 262144),
    baseten_model("zai-org/GLM-5.3-Flash", "GLM 5.3 Flash [Baseten]", True, 262144),
    baseten_model("deepseek-ai/DeepSeek-V4-Pro-0813", "DeepSeek V4 Pro [Baseten]", True, 262144),
    baseten_model("deepseek-ai/DeepSeek-V4-Flash-0731", "DeepSeek V4 Flash [Baseten]", True, 1048576),
    baseten_model("nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B", "Nemotron Ultra [Baseten]", True, 202800),
    baseten_model("zai-org/GLM-5.2", "GLM 5.2 [Baseten]", True, 262144),
    baseten_model("zai-org/GLM-5.2-Fast", "GLM 5.2 Fast [Baseten]", True, 262144),
    # Served but intentionally skipped (too crippled/small for agentic coding):
    #   zai-org/GLM-5.2-1M      - max output capped at 5k
    #   inception/mercury-2     - 8k context
    #   sid/sid-1               - 32k context, 5k max output
]

# Prune Baseten-managed entries whose model is no longer served.
wanted = {m["model"] for m in baseten_models}
kept = []
for m in settings["customModels"]:
    if m.get("baseUrl") == BASE_URL and m.get("model") not in wanted:
        print("  pruned no-longer-served Baseten model: %s" % m.get("model"))
        continue
    kept.append(m)
settings["customModels"] = kept

existing = {m.get("model"): i for i, m in enumerate(settings["customModels"])}
for m in baseten_models:
    name = m["model"]
    if name in existing:
        old = settings["customModels"][existing[name]]
        for k in ("id", "index"):
            if k in old:
                m[k] = old[k]
        settings["customModels"][existing[name]] = m
    else:
        print("  added Baseten model: %s" % name)
        settings["customModels"].append(m)

# Full autonomy + trust everything under $HOME so droid never prompts.
from datetime import datetime, timezone
settings.setdefault("sessionDefaultSettings", {})
settings["sessionDefaultSettings"].update({
    "autonomyMode": "auto-high",
    "interactionMode": "auto",
    "autonomyLevel": "high",
})
settings.setdefault("trustedFolders", {})
settings["trustedFolders"].setdefault(os.path.expanduser("~"), {
    "trustedAt": datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z"),
})

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF
}

# One-shot Factory configuration shared by both bootstrap scripts:
#   1. load .env (BASETEN_API_KEY, FACTORY_API_KEY)
#   2. write Baseten BYOK custom models into ~/.factory/settings.json
#   3. persist FACTORY_API_KEY to shell rc files
#   4. persist FACTORY_DISABLE_KEYRING=1 so droid stores auth in the portable
#      ~/.factory/auth.v2.file + auth.v2.key pair instead of the macOS login
#      keychain — this is what lets `devpod-bundle` carry droid auth to Linux.
# Pass the repo root as $1.
configure_factory() {
  local repo_dir="$1"
  load_env_file "$repo_dir"
  configure_factory_models
  persist_export_to_rc "FACTORY_DISABLE_KEYRING" "1"
  if [[ -n "${FACTORY_API_KEY:-}" ]]; then
    persist_export_to_rc "FACTORY_API_KEY" "$FACTORY_API_KEY"
    echo "FACTORY_API_KEY persisted to shell rc files."
  else
    echo "NOTE: FACTORY_API_KEY is not set in .env; skipping shell rc export."
    echo "      droid will fall back to its OAuth auth file (~/.factory/auth.v2.file)."
  fi
}
