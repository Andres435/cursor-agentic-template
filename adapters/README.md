# `adapters/` — Per-runtime overlays

The repo root names verbs and tiers. Each adapter's `model-usage.md` maps tiers, subagent roles,
and `deepLane`. Verbs: [../_shared/harness-verbs.md](../_shared/harness-verbs.md).

| Adapter | Runtime | `deepLane` |
|---|---|---|
| [cursor/](cursor/README.md) | Cursor | dispatch |
| [claude/](claude/README.md) | Claude Code | dispatch |
| [gpt/](gpt/model-usage.md) | Cursor chat on a GPT picker | inline |
| [codex/](codex/README.md) | Codex | inline |

Hook logic lives once in [`../hooks/core/`](../hooks/core/). `cursor/hooks/` and `claude/hooks/` are thin adapters over it.

## Open a ticket worktree

A worktree ticket's chat must be rooted at the ticket worktree: the `root` that
`scripts/ticket/Resolve-TicketRoot.ps1 -Ticket <ticket> -Json` returns. Shared docs say only that;
how to get there depends on the runtime.

| Runtime | How |
|---|---|
| Cursor | Open the ticket's workspace file (or the worktree folder) and start a new Agent chat in that window. Never call `move_agent_to_root`: Cursor cannot root an agent on a folder of several git repos. |
| Claude Code | Start `claude` (with `--plugin-dir` pointing at this folder) in the worktree root, or change directory there first. |
| Codex | Start Codex in the worktree root. |
