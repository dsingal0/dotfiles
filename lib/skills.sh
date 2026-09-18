# skills.sh - agent skill install + cleanup shared by every bootstrap script.
#
# Sourced by lib/shared.sh; not executable on its own.

# Symlink every <repo>/skills/<name>/SKILL.md into the harnesses' global skills
# dirs. Idempotent. Targets:
#   Factory / droid -> ~/.factory/skills/
#   omp             -> ~/.omp/agent/skills/
# Existing non-symlink dirs are left alone (with a warning).
# $1 = repo root; $2 = space-separated skill names to skip.
install_shared_skills() {
  local repo_dir="$1" exclude_names="${2:-}"
  local skills_src="$repo_dir/skills"

  if [[ ! -d "$skills_src" ]]; then
    echo "NOTE: no skills/ directory at $skills_src; skipping skill install."
    return 0
  fi

  local targets=( "$HOME/.factory/skills" "$HOME/.omp/agent/skills" )
  local target skill_dir name dest count=0
  for target in "${targets[@]}"; do mkdir -p "$target"; done

  echo "Installing shared skills from $skills_src ..."
  for skill_dir in "$skills_src"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_dir="${skill_dir%/}"
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    name="$(basename "$skill_dir")"

    if [[ -n "$exclude_names" && " $exclude_names " == *" $name "* ]]; then
      for target in "${targets[@]}"; do
        dest="$target/$name"
        if [[ -L "$dest" ]]; then
          rm -f "$dest"; echo "  removed excluded skill: $dest"
        elif [[ -e "$dest" ]]; then
          echo "  WARNING: $dest exists and is not a symlink; leaving it alone."
        fi
      done
      echo "  skipped $name (excluded)"; continue
    fi

    for target in "${targets[@]}"; do
      dest="$target/$name"
      if [[ -e "$dest" && ! -L "$dest" ]]; then
        echo "  WARNING: $dest exists and is not a symlink; leaving it alone."
        continue
      fi
      ln -sfn "$skill_dir" "$dest"
    done
    echo "  linked $name"; count=$((count + 1))
  done
  echo "Shared skills installed: $count skill(s) -> factory, omp."
}

# Remove third-party skills from packs this machine should not have. Skill
# names are read from ~/.agents/.skill-lock.json (records each skill's source
# repo), so removal is exact even when two packs ship the same name.
# Pass the pack sources to remove as $@ (e.g. "expo/skills" "emilkowalski/skills").
cleanup_excluded_skill_packs() {
  local sources=("$@")
  [[ ${#sources[@]} -gt 0 ]] || return 0
  local lock="$HOME/.agents/.skill-lock.json"
  [[ -f "$lock" ]] || return 0

  local -a names=()
  local n
  while IFS= read -r n; do
    [[ -n "$n" ]] && names+=("$n")
  done < <(python3 - "$lock" "${sources[@]}" << 'PYEOF'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except (FileNotFoundError, json.JSONDecodeError):
    sys.exit(0)
sources = set(sys.argv[2:])
for name in sorted(data.get("skills", {})):
    if data["skills"][name].get("source") in sources:
        print(name)
PYEOF
)
  [[ ${#names[@]} -eq 0 ]] && { echo "  no excluded pack skills installed."; return 0; }

  echo "Removing excluded pack skills: ${names[*]}"
  # skill names must precede the -a flags (the CLI greedily consumes args after -a).
  npx --yes skills@latest remove -g -y "${names[@]}" -a universal -a droid \
    || echo "WARNING: skill removal reported errors (continuing)."
}

# Install third-party skill packs globally via the skills.sh CLI. Idempotent.
# Packs: mattpocock (always), expo (see $2), emilkowalski (see $1).
# Agents are listed explicitly (eve/promptscript can't take global installs);
# `universal` covers ~/.agents/skills, which omp reads natively.
# Requires node/npx. $1 = include emilkowalski; $2 = include expo.
install_skill_packages() {
  local include_emilkowalski="${1:-false}" include_expo="${2:-true}"

  if ! command -v npx >/dev/null 2>&1; then
    echo "WARNING: npx not found; skipping third-party skill packages."
    return 0
  fi

  local -a excluded=() packs=("mattpocock/skills")
  [[ "$include_expo" == "true" ]] || excluded+=("expo/skills")
  [[ "$include_emilkowalski" == "true" ]] || excluded+=("emilkowalski/skills")
  [[ "$include_expo" == "true" ]] && packs+=("expo/skills")
  [[ "$include_emilkowalski" == "true" ]] && packs+=("emilkowalski/skills")
  [[ ${#excluded[@]} -gt 0 ]] && cleanup_excluded_skill_packs "${excluded[@]}"

  local agent_args=(-a universal -a droid)
  local pack
  for pack in "${packs[@]}"; do
    echo "Installing skill pack: $pack (global)..."
    # --full-depth: mattpocock nests skills under engineering/productivity/etc.
    npx --yes skills@latest add "$pack" -g -y --skill '*' --full-depth \
      "${agent_args[@]}" \
      || echo "WARNING: skill pack install reported errors for $pack (continuing)."
  done

  cleanup_stale_skill_dirs
}

# Remove dotdirs in $HOME whose entire contents are symlinks into
# ~/.agents/skills/ (left by a previous `npx skills add --agent '*'` run).
# Real agent dirs (.cursor, .grok, .factory, .omp) are never touched.
cleanup_stale_skill_dirs() {
  python3 - << 'PYEOF'
import os, glob, shutil
home = os.path.expanduser("~")
removed = 0
for entry in sorted(glob.glob(os.path.join(home, ".*"))):
    name = os.path.basename(entry)
    if name in (".", "..") or not os.path.isdir(entry):
        continue
    has_real = has_skill_links = False
    for root, dirs, files in os.walk(entry, followlinks=False):
        for f in files:
            full = os.path.join(root, f)
            if os.path.islink(full):
                if ".agents/skills" in os.readlink(full): has_skill_links = True
                else: has_real = True
            else:
                has_real = True
        for d in dirs:
            full = os.path.join(root, d)
            if os.path.islink(full) and ".agents/skills" not in os.readlink(full):
                has_real = True
        if has_real: break
    if has_skill_links and not has_real:
        shutil.rmtree(entry); print(f"  removed stale skill dir: {name}"); removed += 1
print(f"Stale skill dirs removed: {removed}")
PYEOF
}

# Remove the stale third-party `baseten` skill (basetenlabs/baseten-skills) at
# every agent skill location so install_shared_skills can symlink the repo's
# static copy (skills/baseten/) in its place. Only removes real dirs/files,
# never symlinks. Idempotent.
cleanup_stale_baseten_skill() {
  local loc removed=0
  for loc in "$HOME/.agents/skills/baseten" "$HOME/.factory/skills/baseten" "$HOME/.omp/agent/skills/baseten"; do
    if [[ -e "$loc" && ! -L "$loc" ]]; then
      rm -rf "$loc"
      echo "  removed stale third-party baseten skill: $loc"
      removed=$((removed + 1))
    fi
  done
  echo "Stale baseten skill entries removed: $removed"
}
