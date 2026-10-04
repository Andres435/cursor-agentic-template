---
name: harness-verbs
description: The neutral verbs the shared workflow uses for IDE actions — ask-user, enter-plan / exit-plan, dispatch, report-context, rename-chat — and the one table that maps each verb to Cursor, Claude Code, and Codex. Core docs use the verb; only this file and adapters/ name IDE tools.
keywords: harness verbs, ask-user, enter-plan, exit-plan, dispatch, report-context, rename-chat, plan mode, IDE neutral, adapter, tool names
---

# Harness Verbs

Skills, playbooks, and agents name a **verb**, never an IDE tool. Each adapter under
[../adapters/](../adapters/README.md) maps the verb to its runtime.

- **`ask-user`** — ask the user a question with explicit options and wait. Never guess an answer.
- **`enter-plan`** — draft in the IDE's plan mode. Pre-approved when a playbook says so; do not ask first.
- **`exit-plan`** — leave plan mode to start building. It runs only after the user approves the
  plan **in chat**; approval is a chat statement, never an IDE button. Do not exit plan mode or
  start building before that. In worktree mode the planning chat never builds.
- **`dispatch(function, tier)`** — run a [subagent function](subagent-functions.md) or Work Plan
  lane on the tier's model ([model-routing.md](model-routing.md)). The adapter maps the role to its
  subagent type and the tier to a model, and declares `deepLane: inline | dispatch`.
- **`report-context`** — record this chat's context occupancy:
  `Set-TicketCtxPct.ps1 -Ticket WI<n> -Phase <start|review|close>`. Omit `-Percent` to use the
  value the IDE hook measured. Pass `-Percent` only when you can read a real number. Never invent
  one; a blank is honest.
- **`rename-chat`** (optional) — rename the chat to `WI<n> <phase>`. Only where the adapter
  supports it; otherwise skip silently.

## Map

| Verb | Cursor | Claude Code | Codex |
|---|---|---|---|
| `ask-user` | `AskQuestion` | `AskUserQuestion` | ask in chat and stop |
| `enter-plan` | `SwitchMode` `target_mode_id: plan` | `EnterPlanMode` | plan mode |
| `exit-plan` | `SwitchMode` back to Agent; never Plan mode's native Build | `ExitPlanMode` after the chat approval (it is the approval step itself) | leave plan mode |
| `dispatch` | `Task` (`subagent_type`, `model`) | `Agent` (`subagent_type`, `model`) | `spawn_agent` (`model`) |
| `report-context` | hook-measured, or the context-window indicator | hook-measured | blank (no Codex hook) |
| `rename-chat` | `cursor-app-control` `rename_chat` | not supported | not supported |

Subagent types and tier models: [Cursor](../adapters/cursor/model-usage.md) ·
[Claude Code](../adapters/claude/model-usage.md) · [Codex](../adapters/codex/model-usage.md) ·
[Cursor GPT](../adapters/gpt/model-usage.md).
