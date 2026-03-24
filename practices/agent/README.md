# Agent Practices

One file per supported agent. Each file documents:
- Available models, their relative cost, and caveats
- Which model to use for each task type (read/write, code gen, planning, debugging)

## Files

| File | Agent |
|---|---|
| `claude.md` | Anthropic Claude CLI (`claude`) |
| `kiro.md` | Kiro CLI (`kiro-cli`) |

## Adding a new agent

Create `practices/agent/<agent-name>.md` following the same structure:
1. Invocation command
2. Model table with cost and notes
3. Task → model assignment table
4. Caveats specific to that agent
