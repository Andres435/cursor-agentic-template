---
name: agents-index
description: Index of workspace agents and routing guidance for ticket work.
---

# Agents Index

Developer overview: [README.md](README.md). Day-to-day usage: [USER-MANUAL.md](USER-MANUAL.md).
What to customize first: [CUSTOMIZE.md](CUSTOMIZE.md).

Before broad searching, check `profile.json` for repo layout, `environments/local-dev.md` for setup,
and agents here for specialists.

**Model usage (Cursor):** Plans → **Grok 4.5**; tasks → Auto/Composer by `[low]|[med]|[high]`; subagents → **Composer 2.5**.
**Model usage (Claude Code):** [adapters/claude/model-usage.md](adapters/claude/model-usage.md).

## Available Agents

> Add your specialist agents to `agents/` and list them here.

- [agents/fullstack-specialist.md](agents/fullstack-specialist.md) — generic fullstack stub; replace with your stack.

## Routing Notes

- Run [skills/workflow/ticket-router/SKILL.md](skills/workflow/ticket-router/SKILL.md) first in `/start-ticket` to emit the work manifest.
- Ticket routing reads `profile.json` — repos, specialists, and `ticketSystem` come from there.
- Domain skills in `skills/domain/` are loaded by the router when `integration` is matched.
- Always a new chat for `/complete-task`.

## Domain Router

| Work area | Route |
|---|---|
| Frontend + backend spanning features | [agents/fullstack-specialist.md](agents/fullstack-specialist.md) |
| _(add project-specific rows)_ | — |
