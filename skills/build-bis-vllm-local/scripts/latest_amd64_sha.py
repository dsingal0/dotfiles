#!/usr/bin/env python3
"""Print the newest vLLM origin/main SHA that has a CI postmerge amd64 image."""

from __future__ import annotations

import subprocess
import sys

REPO = "https://github.com/vllm-project/vllm.git"
IMAGE = "public.ecr.aws/q9t5s3a7/vllm-ci-postmerge-repo"
LIMIT = 30


def run(cmd: list[str], timeout: int = 60) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def commits() -> list[str]:
    local = "/root/repos/vllm"
    if run(["git", "-C", local, "rev-parse", "--is-inside-work-tree"]).returncode == 0:
        run(["git", "-C", local, "fetch", "origin", "main"])
        out = run(["git", "-C", local, "log", "origin/main", "--format=%H", f"-{LIMIT}"])
        if out.returncode == 0 and out.stdout.strip():
            return out.stdout.splitlines()
    out = run(["git", "ls-remote", REPO, "refs/heads/main"])
    if out.returncode != 0:
        print(out.stderr, file=sys.stderr)
        sys.exit(1)
    tip = out.stdout.split()[0]
    # ls-remote only gives tip; walk via GitHub API if no local clone
    import json
    import urllib.request

    url = f"https://api.github.com/repos/vllm-project/vllm/commits?sha=main&per_page={LIMIT}"
    with urllib.request.urlopen(url, timeout=30) as r:
        data = json.load(r)
    return [c["sha"] for c in data] or [tip]


def has_amd64(sha: str) -> bool:
    p = run(["docker", "buildx", "imagetools", "inspect", f"{IMAGE}:{sha}"], timeout=45)
    return p.returncode == 0


def main() -> None:
    for sha in commits():
        ok = has_amd64(sha)
        print(f"{sha} amd={'OK' if ok else 'MISS'}", file=sys.stderr)
        if ok:
            print(sha)
            return
    print("no amd64 postmerge image in last", LIMIT, "commits", file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
