---
name: server-ops
kind: workflow
command: make server-ops
description: Operate on a server — check services, deploy, rollback, read logs
actor: default
runs: once
principles: [security]
---

# Server Agent Operations

## What This Spec Covers

How a ralph loop agent operates when running directly on a server — not inside a Docker sandbox. This applies when the agent is deployed as a service (e.g. on a k3s node, a VPS, or a NixOS host) and needs to interact with the host system: checking service status, reading logs, restarting processes, managing containers, and deploying changes.

This is distinct from the sandbox spec (`sandbox.md`), which covers spawning isolated containers for code execution. Server operations are about managing the infrastructure the app runs on.

## Core Rule: sudo Is Available and Expected

The agent runs as a user with passwordless `sudo` for a defined set of commands. It does not need to ask permission or work around privilege requirements — it uses `sudo` directly for any command that requires it.

This mirrors Loom's server agent model: "You are running on the machine and can check status without SSH — just use sudo."

Passwordless sudo is scoped to the minimum required command set (see below). The agent never runs `sudo su`, `sudo bash`, or any command that escalates to an unrestricted root shell.

## Allowed sudo Commands

These are the only commands the agent may invoke with `sudo`. Any operation outside this list requires a `RALPH_WAITING` pause for human approval.

```
sudo systemctl status <service>
sudo systemctl start <service>
sudo systemctl stop <service>
sudo systemctl restart <service>
sudo journalctl -u <service> [-f] [-n <lines>]
sudo kubectl get <resource> [-n <namespace>]
sudo kubectl describe <resource> <name> [-n <namespace>]
sudo kubectl logs <pod> [-n <namespace>]
sudo kubectl delete pod <name> [-n <namespace>]
sudo kubectl apply -f <manifest>
sudo kubectl rollout status deployment/<name> [-n <namespace>]
sudo kubectl rollout undo deployment/<name> [-n <namespace>]
sudo docker compose -f <file> <subcommand>
sudo docker ps
sudo docker logs <container>
```

Never:
- `sudo su`, `sudo bash`, `sudo sh` — no unrestricted shell escalation
- `sudo rm -rf` — no destructive filesystem operations without explicit human approval
- `sudo chmod 777` or any world-writable permission change
- Any command that modifies `/etc/` without explicit human approval

## Standard Verification Sequence

When the agent deploys a change or restarts a service, it always runs this sequence before declaring success:

1. Check the deployed revision matches the expected commit
2. Check the service restarted (look at start time in `systemctl status`)
3. Check the health endpoint responds correctly
4. Check recent logs for errors (`journalctl -u <service> -n 50`)

Do not output `RALPH_COMPLETE` until all four checks pass.

## Service Management

```bash
# Check status
sudo systemctl status <service>

# Restart after deploy
sudo systemctl restart <service>

# Follow logs live
sudo journalctl -u <service> -f

# Last N lines
sudo journalctl -u <service> -n 100
```

Services the agent manages:
- `rails` (or the app service name defined in `AGENTS.md`)
- `sidekiq` (background jobs)
- `postgres` (if running as a system service rather than in Docker)
- `redis`
- Any service listed in the project's `AGENTS.md` lookup table

## Kubernetes Operations

The agent uses `kubectl` for pod and deployment management. All operations are namespaced — never operate on `--all-namespaces` without explicit human instruction.

```bash
# Check pod status
sudo kubectl get pods -n <namespace>

# Describe a failing pod
sudo kubectl describe pod <name> -n <namespace>

# Read pod logs
sudo kubectl logs <name> -n <namespace>

# Delete a stuck pod (it will be recreated by the deployment)
sudo kubectl delete pod <name> -n <namespace>

# Apply a manifest
sudo kubectl apply -f infra/k8s/

# Check rollout
sudo kubectl rollout status deployment/<name> -n <namespace>

# Roll back
sudo kubectl rollout undo deployment/<name> -n <namespace>
```

**Rollback rule:** if the health check fails after a deploy, the agent automatically runs `kubectl rollout undo` before outputting `RALPH_WAITING` to report the failure. Never leave a broken deployment without attempting rollback first.

## Deploy Flow

```
git push origin <branch>
    ↓
Agent detects new commit (or is triggered via POST /api/agent_runs/start)
    ↓
Build and push image: docker build + push, tagged by git SHA
    ↓
Apply manifests: kubectl apply -f infra/k8s/
    ↓
Wait for rollout: kubectl rollout status
    ↓
Verify: health endpoint + journalctl check
    ↓
RALPH_COMPLETE (or rollback + RALPH_WAITING on failure)
```

Image tags are always git SHAs — never `latest`. The manifest is updated with the new SHA before `kubectl apply`.

## Log Reading

The agent reads logs to diagnose failures, not to monitor continuously. It reads a bounded window — never tails indefinitely in a loop iteration.

```bash
# Last 50 lines of a service
sudo journalctl -u <service> -n 50

# Logs since a specific time
sudo journalctl -u <service> --since "10 minutes ago"

# Pod logs (last 100 lines)
sudo kubectl logs <pod> -n <namespace> --tail=100
```

When diagnosing a failure, the agent reads logs before making any changes. It does not guess at the cause.

## Failure Handling

| Situation | Agent action |
|---|---|
| Service fails to start after restart | Read journalctl, identify error, attempt fix, restart once more, then RALPH_WAITING |
| Pod CrashLoopBackOff | `kubectl describe` + `kubectl logs`, identify cause, RALPH_WAITING with diagnosis |
| Health check fails after deploy | `kubectl rollout undo`, verify rollback succeeded, RALPH_WAITING with failure report |
| Unknown error in logs | RALPH_WAITING with the relevant log excerpt — do not guess |
| Disk full | RALPH_WAITING immediately — do not attempt cleanup without human approval |

The agent never retries a failed operation more than once without human input. Two consecutive failures on the same operation → `RALPH_WAITING`.

## Security Constraints

- Never log or output the contents of `/etc/`, credential files, or environment files
- Never read files outside the project directory and `/var/log/` without explicit instruction
- Never modify system configuration files (`/etc/systemd/`, `/etc/nginx/`, etc.) without explicit human approval via `RALPH_WAITING`
- Shell commands are always passed as argument arrays — no string interpolation of user-supplied values into shell commands
- The agent does not store or transmit server credentials — it operates as the user it was invoked as

## AGENTS.md Requirements

Every project deployed to a server must include a server operations section in `AGENTS.md`:

```markdown
## Server Operations

- Service name: <name>
- Namespace (k8s): <namespace>
- Health endpoint: <url>
- Deploy command: <command>
- Rollback command: kubectl rollout undo deployment/<name> -n <namespace>
- Log command: sudo journalctl -u <name> -n 100
```

The agent reads this section at the start of any server operation. It does not guess service names or namespaces.

## Acceptance Criteria

- Agent uses `sudo systemctl` and `sudo kubectl` directly — no workarounds for privilege
- Agent never runs `sudo bash`, `sudo su`, or unrestricted shell escalation
- Verification sequence (revision + service status + health + logs) runs after every deploy
- Failed deploy triggers `kubectl rollout undo` before `RALPH_WAITING`
- Agent reads logs before making changes when diagnosing a failure
- Agent does not retry a failed operation more than once without human input
- `AGENTS.md` server operations section is present and read before any server operation
- Commands outside the allowed sudo list trigger `RALPH_WAITING` for human approval
