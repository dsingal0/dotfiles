---
name: fix-h100-node-storage
description: Diagnose and fix Crocodile/RKE2 H100 GPU node storage pressure that blocks dev pods from scheduling. Use when a node is NotReady, dev pods are stuck in ContainerCreating/Pending, or kubelet reports EvictionThresholdMet / FreeDiskSpaceFailed on /mnt/nvme.
---

# Fix H100 Node Storage Issues

## Overview

Crocodile/RKE2 H100 nodes host per-user dev StatefulSets (`<user>-dev-pod-crusoe`) that bind-mount a hostPath on to `/mnt/nvme/<user>-devenv-storage` and run Docker-in-Docker in an emptyDir. The NVMe RAID at `/mnt/nvme` also backs `/var/lib/containerd`, so user dev storage and containerd share a single 3.4TB array.

When that array fills past the kubelet image-GC high-water mark (default 85%), the node enters disk-pressure eviction: image blobs get garbage-collected, sandbox images and dev-env images lose blobs, and after a reboot the node comes up `NotReady` with dev pods stuck in `ContainerCreating` ("blob not found"). Symptom in events:

```
Warning  EvictionThresholdMet     ...  Attempting to reclaim ephemeral-storage
Warning  FreeDiskSpaceFailed      ...  Failed to garbage collect required amount of images. ... only found 0 bytes eligible to free.
Warning  FailedCreatePodSandBox    ...  failed to start sandbox ... error unpacking image: blob ... not found
```

## Goal

Free enough space on `/mnt/nvme` that:

- `DiskPressure=False`, node `Ready=True`, and the recurring `EvictionThresholdMet` / `FreeDiskSpaceFailed` events stop.
- The user's dev StatefulSet pod (e.g. `dsingal-dev-pod-crusoe-0`) can schedule and reach `Running`.

## Workflow

### 1. Read the situation from the API

```bash
kubectl get node <node> -o wide
kubectl describe node <node> | tail -120
# In events: look for EvictionThresholdMet, FreeDiskSpaceFailed, NodeNotReady, "blob not found"
kubectl get pod -A --field-selector spec.nodeName=<node> -o wide
kubectl describe pod <user>-dev-pod-crusoe-0 | tail -40
kubectl get sts -n default
```

If `kubectl describe` shows `FailedCreatePodSandBox: blob sha256:... not found` and `Failed to garbage collect ... only found 0 bytes eligible to free`, this is the storage pressure path.

After a reboot, the dev pod may already be `ContainerCreating` simply because the kubelet has only just started and stargz blobs were GC'd; waiting may let it schedule. The durable fix is still clearing `/mnt/nvme`.

### 2. Get a shell on the node

Use `nsender` to launch a privileged `nsenter` pod on the node (gives host hostPID/hostNetwork access). It is installed for this repo at `/Users/dsingal/repos/dotfiles/../baseten/bin/nsender` or as a CLI:

```bash
nsender <node>
# In the resulting shell you are on the host root FS; /mnt/nvme is the shared array.
```

`nsender` is an interactive script — for non-interactive cleanup, run commands via `kubectl exec <me>-nsenter-<node> -- /bin/sh -c '...'`. The exec container sees `/mnt/nvme`.

### 3. Inspect disk, kubelet, and image state

```bash
df -h /                 # root disk (not the issue typically)
df -h /mnt/nvme         # the 3.4T array — this is what goes >85%
du -sh /mnt/nvme/*-devenv-storage | sort -h
du -sh /mnt/nvme/*-docker-data 2>/dev/null | sort -h

systemctl is-active kubelet rke2-agent   # rke2-agent runs kubelet as child; "kubelet" unit may not exist
systemctl status rke2-agent --no-pager | head -30
# Confirm kubelet PID is running:
ps -ef | grep -w kubelet | grep -v grep

CTR=/var/lib/rancher/rke2/data/v*/bin/ctr
$CTR -n k8s.io -a /run/k3s/containerd/containerd.sock images list | head
```

### 4. Decide who owns the bulk

`du -sh /mnt/nvme/*-devenv-storage` reveals the consumers. The `*-docker-data` dirs at the array root are the DinD persistent caches per dev pod and are routinely the largest re-claimable target.

Confirm the user's intent on scope: which users' storage to clean, whether to also stop the matching StatefulSets, and confirm the user understands deletion is irreversible. Use `AskUser`.

### 5. Stop the dev StatefulSets whose storage you will clean

Stop the dev StatefulSet first so its in-pod Docker daemon releases the `*-docker-data` dir. Otherwise `rm` may race with running containers and leave stale mounts.

```bash
kubectl delete sts -n default <user1>-dev-pod-crusoe <user2>-dev-pod-crusoe --cascade=foreground
kubectl get sts,pod -n default
```

Only delete StatefulSets explicitly named by the user; leave others (e.g. `iancarrasco`) untouched unless asked.

### 6. Clean each user's devenv-storage

Per the user's instructions, prune the largest re-generable categories inside `<user>-devenv-storage/`:

- All docker daemon data: any dir named `docker` or `docker-data` containing overlay2/`image`/`containers`/`volumes`/`buildkit`, and top-level `.docker`.
- All `.cache` directories (recursively).
- All `.safetensors` and `.bin` files (recursively). These are model weight files and re-pullable.

Then delete the per-user DinD cache dir at the array root:

- `/mnt/nvme/<user>-docker-data/` entirely.

Do not delete user source trees, git checkouts, or config files. Only delete docker daemon artifacts, caches, and model weight files. Keep `Cargo`/`builds/<repo>` source, `baseten/docker` (when it only contains Dockerfiles — they are tiny source, not daemon data), and dotfiles.

### 7. Verify cleanup

```bash
df -h /mnt/nvme                                  # expect used% to drop well below 85
du -sh /mnt/nvme/*-devenv-storage | sort -h
```

Then confirm node health from the API:

```bash
kubectl get node <node>
kubectl get node <node> -o jsonpath='{range .status.conditions[*]}{.type}={.status} reason={.reason}{"\n"}{end}'
# DiskPressure=False, Ready=True, no eviction warnings
kubectl get events --field-selector involvedObject.name=<node> --sort-by=.lastTimestamp | tail -20
```

### 8. Clean up the debug nsenter pod

```bash
kubectl delete pod <me>-nsenter-<node> --grace-period=5
```

## Reference Sizes (real example)

A single node that was at 87% (450G free) and stuck had these consumers:

```
946G  dsingal-devenv-storage      ->  29G   (del 233G cache, 755G safetensors, 1.9G bin, 0.6G docker-data)
627G  chriswirick-devenv-storage  ->  2.7G  (del 662G docker daemon overlay2)
549G  youngzheng-devenv-storage   -> 231G  (del 404G docker-data dir, 282G cache)
 42G  davidoy-devenv-storage      ->  6.7G  (del 124G docker-data dir, 37G safetensors)
```

After cleanup: `/dev/md127 3.4T  587G  2.8T  18%`. Recurring `EvictionThresholdMet` stopped; node stayed `Ready`.

## Decision Rules

- `Kubelet stopped posting node status` right after a reboot is normal during recovery — kubelet just started; wait ~1-2 min before declaring it broken.
- The recurring disk-pressure root cause is the user `*-devenv-storage` + `*-docker-data` dirs on `/mnt/nvme`, not containerd's internal image set (those are small, marked `io.cri-containerd.image=managed`, and mostly re-pullable).
- Only delete storage for users the user explicitly named. Default to NOT touching iancarrasco unless asked.
- Never `rm -rf` a user's whole `<user>-devenv-storage`. Use targeted pruning: docker daemon dirs, `.cache`, `.safetensors`, `.bin`. Source code stays.
- A `docker` dir at any depth is a daemon root only if it contains overlay2/image/containers/volumes/buildkit, otherwise it's a source-tree dir of Dockerfiles — leave it.
- Don't conflate root disk `/dev/vda1` with `/dev/md127`; root being 45% full does not cause the H100 dev-pod eviction, `/mnt/nvme` does.

## Good Output

When done, report:

- the root cause (disk pressure on `/mnt/nvme`; blob losses after reboot)
- before/after `df -h /mnt/nvme`
- per-user size reductions (before -> after) and what categories were deleted
- which StatefulSets were deleted and which were left untouched
- node conditions: `Ready=True`, `DiskPressure=False`, health checks passing
- whether the user's target dev pod now schedules

Example summary:

```text
Root cause: /mnt/nvme was at 87% used (450G free) past kubelet image-GC high threshold,
causing EvictionThresholdMet + FreeDiskSpaceFailed for 3+ days; after the reboot
stargz/containerd GC'd sandbox and gpu_dev_env blobs so dsingal's pod was stuck in
ContainerCreating until blobs were repulled.

Per user (devenv-storage, before -> after):
  dsingal     946G -> 29G   (docker data, 233G .cache, 755G safetensors, 1.9G bin)
  chriswirick 627G -> 2.7G  (662G docker overlay2)
  youngzheng  549G -> 231G  (404G docker-data dir, 282G .cache)
  davidoy      42G -> 6.7G  (124G docker-data dir, 37G safetensors)
Plus all 4 /mnt/nvme/<user>-docker-data dirs removed.

df -h /mnt/nvme: /dev/md127 3.4T  587G  2.8T  18%
Node rke-h100-580-cuda-13-pll5u Ready=True, DiskPressure=False, all Baseten/GPU health checks passing.
StatefulSets deleted: dsingal, chriswirick, youngzheng, davidoy dev-pod-crusoe.
Left untouched: iancarrasco-dev-pod-crusoe.
```

## Anti-Pattern

Do not stop here:

```text
Node is Ready now, dev pod scheduled.
```

That is incomplete unless you also cleared the `/mnt/nvme` storage pressure — without that, the eviction loop recurs within days and the next reboot trips `blob not found` again.

Do not also:

- `rm -rf /mnt/nvme/<user>-devenv-storage` wholesale (destroys source + dotfiles).
- delete `iancarrasco` or any other user not explicitly named by the user.
- assume `/` being full is the issue; the culprit is `/mnt/nvme`.
- skip stopping the StatefulSet before `rm`-ing its live `*-docker-data` — the in-pod Docker daemon can race your `rm` and leave stale overlay mounts.
