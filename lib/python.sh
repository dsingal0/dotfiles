# python.sh - shared python/JSON helpers used across the lib modules.
#
# Sourced by lib/shared.sh; not executable on its own.

# Resolve the latest GitHub release tag for <owner>/<repo>. Prints the tag, or
# nothing on fetch failure (callers skip rather than pin a stale release).
gh_latest_tag() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["tag_name"])' 2>/dev/null
}

# Write/merge a single MCP server entry into a harness's mcp.json. Preserves
# other servers; creates the file (and parent dir) when missing.
#   upsert_mcp_server <mcp.json-path> <name> <url> [extra-json]
upsert_mcp_server() {
  local path="$1" name="$2" url="$3" extra="${4:-"{}"}"
  MCP_PATH="$path" MCP_NAME="$name" MCP_URL="$url" MCP_EXTRA="$extra" \
    python3 - <<'PYEOF'
import json, os

path = os.path.expanduser(os.environ["MCP_PATH"])
try:
    with open(path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}
data.setdefault("mcpServers", {})
entry = {"type": "http", "url": os.environ["MCP_URL"]}
entry.update(json.loads(os.environ["MCP_EXTRA"]))
data["mcpServers"][os.environ["MCP_NAME"]] = entry
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
}
