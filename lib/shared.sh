#!/usr/bin/env bash
# shared.sh - aggregator for the lib/ modules. Source this one file to get every
# bootstrap helper:
#
#   . "$SCRIPT_DIR/lib/shared.sh"
#
# Module map (sourced in dependency order):
#   rc.sh        shell rc-file + env helpers (append_once, managed blocks, PATH)
#   python.sh    shared python/JSON helpers (mcp upsert, github release tag)
#   omp.sh       oh-my-pi install + config + runlayer MCP + RTK init
#   factory.sh   Factory (droid) BYOK custom models + auth
#   skills.sh    agent skill install + cleanup
#   tools.sh     tool installers (droid, baseten, croc, venv, node, rust, uv)
#   bootstrap.sh bootstrap_common — the shared post-package-install sequence
#
# This file is NOT executable on its own; it must be sourced after SCRIPT_DIR is
# set.

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
for _m in rc python omp factory skills tools bootstrap; do
  . "$_lib_dir/$_m.sh"
done
unset _lib_dir _m
