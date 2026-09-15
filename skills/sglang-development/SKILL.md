---
name: sglang-development
description: Develop, export, test, review, and rebase SGLang changes in Baseten's serving integration. Use when changing the SGLang release pin, maintaining docker/sglang/patches, running patch unit tests in a built image, or working on the make init_sglang and make commit_sglang workflow.
---

# SGLang development

Keep the upstream delta small, independently reviewable, and suitable for upstreaming.
Follow the repository's AGENTS.md for toolchain, testing, and image-build instructions.

## Base and patch stack

Work from the repository's `mp/baseten_dynamo/cache_aware_routing_trtllm/` directory.
Read `versions/sglang.env`, `Makefile`, `docker/gpu.sglang.Dockerfile`, and the relevant
files in `docker/sglang/patches/` before changing the stack.

- Prefer a published SGLang release as the base. Keep the source pin and base image
  consistent. Document the concrete reason if an unreleased commit is necessary.
- Prefix every patch filename with a unique numeric application index. Use consistent
  zero padding, and apply patches in numeric order in both development and image builds.
- Allocate new indices as the highest existing index plus one, not the file count.
- When a feature needs another patch later in the stack, add a feature-part suffix:
  `001_feature_a.patch`, `002_feature_b.patch`, `010_feature_a_2.patch`,
  `011_feature_a_3.patch`. The prefix orders the stack; the suffix orders that feature's parts.
- Keep dependent patches in their necessary order. Do not group a feature's parts
  together if intervening patches are dependencies.
- Keep patches self-contained: include every required new SGLang source file as a
  new-file diff in its owning patch, not a separate Docker `COPY` or sidecar source file.
  The pinned release plus the ordered patch stack must reproduce the complete patched
  SGLang source tree. Tests can remain separate.

## Required patch description

Start every patch with a detailed plain-text description before the first `diff --git`.
Explain the problem, implementation, affected paths, important constraints, and why the
patch is needed on the pinned release. Record dependencies and validation evidence;
distinguish completed checks from checks still needed. A title alone is insufficient.

For a cherry-pick, **clearly state the upstream PR URL and source commit SHA** at the top.
Identify whether it is an exact cherry-pick or an adapted backport, and describe any
local adaptations. Preserve upstream attribution. If no upstream PR exists, explicitly
say so and link the source commit; never invent a PR or label original work a cherry-pick.
For original work, include an upstream issue or PR when one exists.

Example header structure (replace placeholders with actual details):

```text
Title: <specific change>
Origin: <original change | exact cherry-pick | adapted backport>
Upstream PR: <URL, or explicitly none>
Source commit: <SHA for a cherry-pick>

Problem: <observable failure or measured limitation on the pinned release>
Implementation: <what changes, why it works, and relevant invariants>
Dependencies: <earlier patches, if any>
Adaptations: <local differences from upstream, if any>
Validation: <correctness/performance checks and remaining limitations>

diff --git ...
```

## Development workflow

The Make targets use `bin/sglang_dev.py` and an ignored `sglang/` clone, independent
of `DYNAMO_VARIANT`. Override `SGLANG_SOURCE_DIR` for another checkout location and
`SGLANG_GIT_URL` for another upstream. Existing checkout directories are never overwritten.

1. Run `make init_sglang`. It prepares the recorded release and ordered patches in a
   temporary clone, publishing `sglang/` only after initialization succeeds. On failure,
   fix the cause and rerun the command; an existing checkout is never overwritten.
   Initialization uses `git apply --index`; Docker uses `git apply`, preserving binary
   patches, file modes, and deletions. Do not silently skip failed patches or accept fuzzy application.
2. Make the change in that SGLang checkout. Prefer upstream/native functionality;
   keep Baseten-specific integration in Baseten code when it avoids an SGLang patch.
   Validate the affected behavior with focused tests and performance checks where relevant.
3. Stage only the intended source changes with `git -C sglang add <paths>`, then run
   `make commit_sglang FEATURE=feature_name DESCRIPTION=/path/to/description.txt`.
   The description file contains the required header above, without a diff. The target
   creates a local source commit and the next numbered patch with the required
   header and feature-part suffix when applicable. Export only the incremental change
   beyond the already-applied stack, including intended new files and deletions, not
   the entire release-to-worktree diff. Existing patches are not rewritten. Unstaged
   tracked changes and empty exports are rejected; untracked files are excluded unless staged.
4. Inspect the generated patch and replay the complete stack in a clean checkout.
   Verify the build applies the same ordered stack. Rebuild affected compiled extensions
   when C++/CUDA changes require it; a Python-only test cannot validate those changes.
   Run the affected unit tests in the resulting image using the flow below.
5. Stage the intended files with `git add` and commit normally when requested.
   Exporting a patch is separate from committing the Baseten repository. Do not infer
   permission to push, build images, or deploy from a request to edit a patch.

### Interrupted exports

If the source commit succeeds but export fails, fix the underlying error and run
`make export_sglang`; do not create another commit. It exports valid pending patch
commits or completes the interrupted export without duplicating them.

Exports record before/after patch contents and workflow state in
`sglang/.git/sglang-export.json` before replacing files atomically. Keep this journal
and `sglang-stack.json` intact until recovery completes. Recovery refuses unrelated
patch edits or an unexpected source HEAD; preserve that work and resolve the mismatch
before retrying, rather than bypassing the checks.

## Unit tests in the built image

1. Build an image containing the source changes, either through `dynamo-push.yml`
   using the repository's `dynamo-image-build` skill, or locally in a supported
   GPU development environment. Follow repository restrictions: do not build or pull
   serving images on a thin agent host.
2. On a test machine with Docker and the NVIDIA runtime, select that exact image tag
   or digest. Match the GPU architecture to the kernels under test. Bind-mount the
   test directory read-only; keep the image's SGLang, Baseten helpers, compiled
   extensions, and dependencies intact. Do not mount a source checkout over them.
3. From `mp/baseten_dynamo/cache_aware_routing_trtllm/`, run the existing SGLang patch
   unit tests (`docker/sglang/tests/test_sglang_*.py`, which use Python's built-in unittest):

```bash
SGLANG_TEST_IMAGE='your-built-image:exact-tag'
docker run --rm --gpus all --entrypoint python3 "$SGLANG_TEST_IMAGE" \
  -c 'import torch; assert torch.cuda.is_available(), "CUDA unavailable; GPU tests would skip"'
docker run --rm --gpus all \
  --mount "type=bind,src=$PWD/docker/sglang/tests,dst=/opt/sglang-tests,readonly" \
  --env PYTHONDONTWRITEBYTECODE=1 \
  --workdir /opt --entrypoint python3 "$SGLANG_TEST_IMAGE" \
  -m unittest discover -s /opt/sglang-tests -p 'test_sglang_*.py' -v
```

Narrow `-p` to a specific test filename for iteration. Test-only edits need no image
rebuild because the tests are mounted; source or patch edits do. Do not upgrade the
image's Torch/CUDA/SGLang packages to make a test pass.

Record the image, GPU, command, failures, and skips. A CPU-only run (omit `--gpus all`)
can check CPU helpers but is not GPU validation. Inspect architecture-specific skips
even when CUDA is available. Docker-build smoke checks alone do not validate GPU
graphs or kernels, and unit tests do not replace serving correctness/performance tests.

## Release upgrades

Start an interactive native Git rebase:

```bash
make replay_sglang VERSION=vX.Y.Z
```

The interactive todo uses one commit per numbered patch. Keep the patch filename as
each commit's subject and its detailed description as the body. Keep the automatic
`exec` entries: each exports the preceding rebased patch before the next patch runs.
For an agent that wants to accept the existing todo order without opening an editor:

```bash
GIT_SEQUENCE_EDITOR=true make replay_sglang VERSION=vX.Y.Z
```

On conflict, resolve the source files in `sglang/`, then use ordinary Git commands:

```bash
git -C sglang add <resolved-paths>
GIT_EDITOR=true git -C sglang rebase --continue
```

Use `git -C sglang rebase --skip` only after confirming upstream covers the patch;
omit `GIT_EDITOR=true` when editing a commit's description. Each successful pick or
conflict resolution automatically regenerates that existing numbered patch through
`export_sglang`; it does not allocate a new patch number. Unreplayed patches remain
untouched. The final export reconciles the complete stack and removes skipped/dropped
patches. Normal continue/skip completion needs no second Make call.
An interactive `edit` stop remains a pending rebase; amend the source commit and
continue normally. If an automatic export fails, fix the error and run
`git -C sglang rebase --continue` to retry its rescheduled export.

To abort, run `git -C sglang rebase --abort`, then `make export_sglang` to restore the
original patch files. This also handles an interrupted export using its journal.
Git itself restores only the source clone, not files in the enclosing Baseten repository.

Concurrent patch-file edits cause export to refuse rather than overwrite them; a
failed export is rescheduled by Git. Keep edits to descriptions in the rebased commit
messages. If automatic exec entries were removed manually, run `make export_sglang`
after the rebase to reconcile the stack. Update `versions/sglang.env` source/image pins
explicitly after reviewing the result; replay does not select or build a serving image.

1. Select the new release and replay patches **one by one in numeric order**.
2. For each patch, inspect the new upstream implementation first. If upstream now
   implements the feature or fix adequately, take upstream and drop the local patch.
3. Resolve the current patch's conflicts semantically and validate it before proceeding
   to the next. Do not bulk-force the old stack onto changed upstream code.
4. Retain a patch only for an objectively demonstrated problem that it solves better
   than the available upstream behavior. Back that claim with correctness evidence or
   representative measurements, not historical investment or stylistic preference.
5. Regenerate each retained incremental patch and update its description/provenance.
   Check dependencies after dropping patches. Numeric gaps are fine; avoid unrelated renumbering.
6. Validate the full stack from the clean release base, including applicable kernel
   builds and serving tests. Keep the remaining delta minimal and work toward upstreaming it.
