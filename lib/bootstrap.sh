# bootstrap.sh - the single shared post-package-install sequence, run by every
# platform bootstrap after its toolchain (nvm/node, uv, rust, brew formulae)
# is in place.
#
# Sourced by lib/shared.sh; not executable on its own.
#
#   bootstrap_common <repo_dir> [skill_excludes] [emilkowalski] [expo]
#
#     repo_dir        repo root (SCRIPT_DIR)
#     skill_excludes  space-separated skills to skip ("" = install all)
#     emilkowalski    "true" to install the emilkowalski skill pack
#     expo            "true" to install the expo skill pack

bootstrap_common() {
  local repo_dir="$1"
  local skill_excludes="${2:-}"
  local pack_emil="${3:-false}" pack_expo="${4:-false}"

  load_env_file "$repo_dir"

  # --- omp + droid harnesses -------------------------------------------------
  install_omp
  configure_omp
  install_global_agents_md "$repo_dir"
  configure_runlayer_mcp
  install_droid

  # --- shell env -------------------------------------------------------------
  link_repo_files "$repo_dir"
  persist_local_bin
  link_profile_to_bashrc
  tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
  configure_rtk

  # --- git identity ----------------------------------------------------------
  echo "Configuring git identity..."
  git config --global user.name "Dhruv Singal"
  git config --global user.email "dhruv.singalabc@gmail.com"

  # --- Factory BYOK models + auth --------------------------------------------
  configure_factory "$repo_dir"

  # --- skills ----------------------------------------------------------------
  cleanup_stale_baseten_skill
  install_shared_skills "$repo_dir" "$skill_excludes"
  install_skill_packages "$pack_emil" "$pack_expo"

  # --- remaining tools -------------------------------------------------------
  install_baseten_cli
  command -v croc >/dev/null 2>&1 || ensure_croc
  install_herdr_completions
  ensure_venv
}
