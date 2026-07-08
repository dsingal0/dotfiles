---
name: rebase-all-prs
description: Find all open PRs across your repos and rebase them onto the latest upstream default branch. Use when you want to update all your PRs at once, or when PRs are failing CI due to stale base branches.
---

# Rebase All Open PRs

## Overview

Use `gh` CLI to discover every open PR authored by you across your repos, then rebase each PR branch onto the latest target branch and force-push. For forked repos, sync the fork from upstream first.

## Repos and Target Branches

| Repo | Target branch | Fork? | Upstream |
|------|--------------|-------|----------|
| `basetenlabs/dynamo` | `main-v1.2.0` | No | - |
| `basetenlabs/baseten` | `master` | No | - |
| `basetenlabs/bei` | `baseten` | No | - |
| `dsingal0/vllm` | `main` | Yes | `vllm-project/vllm` |

To discover the default branch for any repo: `gh repo view <repo> --json defaultBranchRef,parent --jq '.defaultBranchRef.name'`.

## Workflow

### 1. Find all open PRs

For non-fork repos, list PRs directly from the repo. For fork repos (e.g. `dsingal0/vllm`), PRs are opened against the upstream repo (`vllm-project/vllm`), so query the upstream repo with `--author "dsingal0"`:

```bash
# Non-fork repos
for repo in basetenlabs/dynamo basetenlabs/baseten basetenlabs/bei; do
  echo "=== $repo ==="
  gh pr list --repo "$repo" --author "@me" --state open \
    --json number,title,headRefName,baseRefName,url --limit 50
  echo ""
done

# Fork: PRs live on the upstream repo, authored from the fork
echo "=== vllm-project/vllm (from dsingal0 fork) ==="
gh pr list --repo vllm-project/vllm --author "dsingal0" --state open \
  --json number,title,headRefName,headRepository,baseRefName,url --limit 50
```

### 2. Ensure local clones exist and are up to date

For each repo that has open PRs, make sure a local clone exists and fetch the latest:

```bash
# Clone if missing
git clone git@github.com:<repo>.git /root/<dir>

# Fetch latest
cd /root/<dir> && git fetch origin --prune
```

Local clone paths used on this machine:

| Repo | Local path |
|------|-----------|
| `basetenlabs/baseten` | `/root/baseten` |
| `basetenlabs/dynamo` | `/root/baseten_dynamo` |
| `basetenlabs/bei` | `/root/bei` |
| `dsingal0/vllm` | `/root/dsingal_vllm` |

### 3. For forked repos: sync fork from upstream first

For `dsingal0/vllm` (fork of `vllm-project/vllm`), sync the fork's main branch from upstream before rebasing:

```bash
cd /root/dsingal_vllm
git remote add upstream https://github.com/vllm-project/vllm.git 2>/dev/null || true
git fetch upstream
git checkout main
git merge --ff-only upstream/main
git push origin main
```

Ensure the fork's origin remote uses SSH (HTTPS will fail with auth): `git remote set-url origin git@github.com:dsingal0/vllm.git`.

### 4. Rebase each PR branch

For each PR, checkout the head branch, rebase onto the target, and force-push. For fork repos, rebase onto `upstream/<target>` instead of `origin/<target>`:

```bash
TARGET=<target_branch>  # e.g. master, main-v1.2.0, baseten, main
REMOTE=origin            # use 'upstream' for forked repos (e.g. dsingal0/vllm)

git checkout <pr_branch>
# Stash if there are unstaged changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  git stash
  STASHED=1
fi
git rebase $REMOTE/$TARGET
# If conflicts arise, resolve them, then:
#   git add <resolved_files>
#   git rebase --continue
git push --force-with-lease origin <pr_branch>
[ "$STASHED" = "1" ] && git stash drop
```

### 5. Handling worktrees

If a branch is checked out in a git worktree (e.g. `/root/kvexp/worktree-fix`), you cannot `git checkout` it from the main repo. Instead, rebase from inside the worktree:

```bash
cd <worktree_path>
git rebase origin/<target>
git push --force-with-lease origin <pr_branch>
```

List worktrees with: `git worktree list`

### 6. Handling complex conflicts

When a PR has many conflicts (e.g. an old PR that accumulated unrelated commits), consider cherry-picking only the relevant commits onto a fresh branch:

```bash
git checkout origin/<target>
git checkout -b <pr_branch>-rebase
git cherry-pick <relevant_commit_hash>
# Resolve conflicts if needed
git branch -D <pr_branch>
git branch -m <pr_branch>-rebase <pr_branch>
git push --force-with-lease origin <pr_branch>
```

For lockfile conflicts (uv.lock, etc.), prefer taking the upstream version (`git checkout --ours <file>` during rebase, since `--ours` = the new base = upstream).

### 7. Verify

After rebasing, verify the PRs show as updated on GitHub:

```bash
gh pr view <number> --repo <repo> --json updatedAt,state
```

## Conflict Resolution Strategy

During a `git rebase`:
- `--ours` = the new base (upstream target branch)
- `--theirs` = the commit being replayed (your PR's commit)

Default to taking `--ours` for:
- Lockfiles (`uv.lock`, `go.sum`, etc.) - regenerate locally if needed after rebase
- Generated files
- Config files where upstream has newer values

Take `--theirs` for:
- Source files where your PR intentionally changes the value
- New files added by your PR

For commits that are already in upstream (e.g. a feature that was separately merged), use `git rebase --skip` to drop them.

## Notes

- Always use `--force-with-lease` instead of `--force` to avoid overwriting others' changes.
- For forks, the PR head branch lives on the fork (`dsingal0/vllm`), not the upstream repo.
- PRs with `headRepositoryOwner` matching the repo owner (e.g. `basetenlabs`) are in-repo branches, not fork branches.
- Check `gh repo view <repo> --json parent` to determine if a repo is a fork.
