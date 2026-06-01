---
name: remove-dynamo-deployment
description: dynamo deployment cleanup, kv_router_v2, mixed_worker, worker_v2, planner, nats, etcd. Use when stopping a running Dynamo deployment on a shared node, especially if killed processes get resurrected.
---

# Remove Dynamo Deployment

Use this skill when a running Dynamo deployment needs to be stopped from a shared node and simple `kill` of Python child processes is not sufficient.

The key rule: remove the supervisor, not just the listener.

## Why

On these nodes, Dynamo processes are often launched inside Docker containers. The visible listeners are usually child processes like:

- `python3 components/mixed_worker.py`
- `python3 components/worker_v2.py`
- `python3 components/kv_router_v2.py`
- `python3 components/planner.py`

Those children may be re-spawned by:

- `containerd-shim-runc-v2`
- Docker restart policy
- wrapper shells inside the container

If you only kill the child Python process, the deployment may come back.

## Goal

Fully remove the deployment so that:

- listener ports are gone
- supervising shims/containers are gone
- support services like deployment-specific `nats-server` and `etcd` are gone
- GPUs used by that deployment are released

## Workflow

### 1. Identify the deployment by ports and commands

Check common Dynamo ports first:

```bash
ss -ltnp '( sport = :8000 or sport = :8001 or sport = :8003 or sport = :4222 or sport = :2379 or sport = :7003 or sport = :7006 or sport = :9093 or sport = :9095 or sport = :9096 )'
```

Then inspect likely processes:

```bash
ps -o pid=,ppid=,user=,etimes=,cmd= -p <pid1>,<pid2>,...
pgrep -af 'components/(mixed_worker|worker_v2|kv_router_v2|planner)|nats-server|etcd'
```

### 2. Trace each child to its supervisor

For each Dynamo child PID, inspect its parent chain.

Look for:

- `/usr/bin/containerd-shim-runc-v2 -namespace moby -id <container_id>`
- wrapper shells like `/bin/sh -c python3 components/...`

Useful commands:

```bash
ps -o pid=,ppid=,cmd= -p <child_pid>,<parent_pid>
tr '\0' ' ' </proc/<shim_pid>/cmdline
```

If the child is inside a container, the shim or container is the real removal target.

### 3. Prefer removing the container or shim

Preferred order:

1. `docker rm -f <container_id>` if Docker can resolve the container
2. Otherwise kill the supervising `containerd-shim-runc-v2`
3. Only kill child Python processes as a fallback or to accelerate teardown

Reason: if the supervisor survives, the child may respawn.

### 4. Remove support services from the same deployment

Also stop deployment-specific:

- `nats-server`
- `etcd`
- `docker-proxy` listeners exposing `4222` and `2379`

Do not kill unrelated system or cluster services. Match by age, parent chain, config path, and proximity to the Dynamo deployment.

### 5. Re-check for respawn

After stopping the obvious processes, immediately re-run:

```bash
pgrep -af 'components/(mixed_worker|worker_v2|kv_router_v2|planner)|nats-server|etcd'
ss -ltnp '( sport = :8000 or sport = :8001 or sport = :8003 or sport = :4222 or sport = :2379 or sport = :7003 or sport = :7006 or sport = :9093 or sport = :9095 or sport = :9096 )'
```

If something respawns, trace its new parent again and remove that supervisor too.

Treat respawn as evidence that you killed the wrong layer.

### 6. Verify GPU cleanup

Check remaining GPU compute processes:

```bash
nvidia-smi --query-compute-apps=pid,process_name,gpu_uuid,used_gpu_memory --format=csv,noheader
```

If a remaining GPU process is not part of the Dynamo deployment, call that out explicitly instead of killing it blindly.

## Decision Rules

- Do not assume every `vllm` or `VLLM::EngineCore` process belongs to the Dynamo deployment.
- Distinguish Dynamo worker processes from unrelated standalone `vllm serve` jobs.
- Ports being free is necessary but not sufficient; check for leftover supervisor processes too.
- A listener disappearing after `kill` does not mean cleanup is complete.
- If Docker cannot resolve a container ID but the shim still exists, kill the shim.

## Good Output

When done, report:

- what was stopped
- whether anything respawned during cleanup
- that the target ports are free
- whether any unrelated GPU jobs remain

Example summary:

```text
Stopped the Dynamo frontend, worker, router, planner, NATS, and etcd processes.
One router respawned under a surviving containerd shim; stopped the shim and verified it stayed down.
All target Dynamo ports are now free.
One separate non-Dynamo VLLM job remains on GPU 0.
```

## Anti-Pattern

Do not stop here:

```text
Killed mixed_worker.py and kv_router_v2.py.
```

That is incomplete unless you also verified the supervisor/container is gone and the processes did not come back.
