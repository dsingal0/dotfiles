# rc.sh - shell rc-file + env helpers shared by every bootstrap script.
#
# Sourced by lib/shared.sh; not executable on its own.

# Append a line to a file only if it is not already present.
append_once() {
  local file="$1" line="$2"
  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# Source the repo's .env (if present) so BASETEN_API_KEY / FACTORY_API_KEY /
# OPENROUTER_API_KEY are exported for the config functions. Pass the repo root.
load_env_file() {
  local repo_dir="$1"
  if [[ -f "$repo_dir/.env" ]]; then
    set -a; source "$repo_dir/.env"; set +a
  fi
}

# Replace the block between two markers in a single file with a fresh body, or
# append it if absent. Idempotent.
#   write_managed_block <file> <open_marker> <close_marker> <body>
write_managed_block() {
  local file="$1" open_m="$2" close_m="$3" body="$4"
  touch "$file"
  OPEN_M="$open_m" CLOSE_M="$close_m" BODY="$body" python3 - "$file" <<'PYEOF'
import os, re, sys

path = sys.argv[1]
block = "%s\n%s\n%s" % (os.environ["OPEN_M"], os.environ["BODY"], os.environ["CLOSE_M"])
try:
    content = open(path).read()
except FileNotFoundError:
    content = ""
pat = re.compile(
    r"\n?" + re.escape(os.environ["OPEN_M"]) + r".*?" + re.escape(os.environ["CLOSE_M"]) + r"\n?",
    re.DOTALL,
)
content = pat.sub("\n", content).rstrip()
if content:
    content += "\n\n"
open(path, "w").write(content + block + "\n")
PYEOF
}

# Apply write_managed_block to ~/.bashrc always and ~/.zshrc when it exists.
write_managed_rc_block() {
  local open_m="$1" close_m="$2" body="$3" rc
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ "$rc" == "$HOME/.zshrc" && ! -f "$rc" ]] && continue
    write_managed_block "$rc" "$open_m" "$close_m" "$body"
  done
}

# Persist `export <VAR>=<value>` into shell rc files inside a managed block so
# re-runs update rather than duplicate. The value is single-quoted (embedded
# quotes escaped).
persist_export_to_rc() {
  local var="$1" value="$2"
  [[ -z "$value" ]] && return 0
  local qesc="'\''"
  local escaped="${value//\'/${qesc}}"
  write_managed_rc_block \
    "# >>> ${var} (managed by dotfiles setup) >>>" \
    "# <<< ${var} <<<" \
    "export ${var}='${escaped}'"
}

# Persist ~/.local/bin onto PATH in shell rc files (managed block).
persist_local_bin() {
  write_managed_rc_block \
    "# >>> ~/.local/bin on PATH (managed by dotfiles setup) >>>" \
    "# <<< ~/.local/bin >>>" \
    'export PATH="$HOME/.local/bin:$PATH"'
}

# Login shells (tmux panes run `-bash`) read ~/.profile, not ~/.bashrc, where
# installers append PATH setup. Bridge the two so new panes pick up tool PATHs.
link_profile_to_bashrc() {
  if [[ -f "$HOME/.profile" ]] && ! grep -qxF '. "$HOME/.bashrc"' "$HOME/.profile"; then
    echo '. "$HOME/.bashrc"' >> "$HOME/.profile"
  fi
}
