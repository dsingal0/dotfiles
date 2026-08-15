# Global Agent Instructions

These rules apply to every project.

1. **NEVER use `/tmp`** (or any system temp directory) for file operations. Use a project-local or otherwise designated work directory instead.
2. **ALWAYS use lowercase** for file and directory names.
3. **Git worktrees belong OUTSIDE the primary project folder** — create them in the directory above the Git repo (i.e. as siblings of the project root).
4. **Use host networking for all Docker operations** — pass `--network host` to `docker run` and `docker build`, or set `network_mode: host` in Docker Compose, unless there is a specific reason not to.
