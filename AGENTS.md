---
name: agents-index
description: Index of workspace agents and routing guidance for ticket work.
---

# Agents Index

Developer overview: [README.md](README.md). Day-to-day usage: [USER-MANUAL.md](USER-MANUAL.md).
What to customize first: [CUSTOMIZE.md](CUSTOMIZE.md).

Before broad searching, check `profile.json` for repo layout, `environments/local-dev.md` for setup,
and agents here for specialists.

Work runs on tiers ([_shared/model-routing.md](_shared/model-routing.md)). The IDE adapter maps them. Verbs: [_shared/harness-verbs.md](_shared/harness-verbs.md).

## Available Agents

> Add your specialist agents to `agents/` and list them here.

- [agents/fullstack-specialist.md](agents/fullstack-specialist.md) — generic fullstack stub; replace with your stack.

## Routing Notes

- Run [skills/ticket-router/SKILL.md](skills/ticket-router/SKILL.md) first in `/start-ticket` to emit the work manifest.
- Ticket routing reads `profile.json` — repos, specialists, and `ticketSystem` come from there.
- `skills/environment-context` matches cards under `environments/` when `integration` is set.
- Branch mode is three chats. `/start-ticket` plans and builds in chat 1. `/review-changes` and `/complete-task` are new chats.

## Domain Router

| Work area | Route |
|---|---|
| Frontend + backend spanning features | [agents/fullstack-specialist.md](agents/fullstack-specialist.md) |
| _(add project-specific rows)_ | — |
