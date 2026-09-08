# cursor-agentic-template

A Cursor AI workflow template for ticket-driven development. Clone or use this as a GitHub template,
then customize for your project — no TMO or project-specific content included.

> **This repo is the `.cursor` folder** — place it at `<your-app>/.cursor` or at
> `source/repos/.cursor` in a multi-repo workspace.

---

## What you get

- **Ticket workflow** — `/start-ticket`, `/implement`, `/complete-task`, `/prep-pr` slash commands
  with planning, code review, and retrospective built in.
- **Hook suite** — `sessionStart` (context hydration), `closeout-read-guard`, `git-commit-ticket-id`,
  `preCompact` nudge, `ticket-command-nudge`.
- **Smart routing** — ticket router reads `profile.json` and loads only the docs this ticket needs.
- **Subagent fan-out** — parallel repo scope, branch setup, verify, and review per the plan.
- **Generic core** — no stack-specific defaults. Start with `npm run dev`; replace as needed.

---

## Quick start

### New project (use this template)

1. Click **Use this template** on GitHub (or `git clone` + delete `.git`).
2. Place the folder at `<your-app>/.cursor` (or `source/repos/.cursor` for multi-repo).
3. **Open `CUSTOMIZE.md`** and work through the checklist — it is the only file you must edit.
4. Bootstrap your machine once:
   ```powershell
   .\.cursor\scripts\machine\Initialize-WorkflowMachine.ps1
   ```
5. Start your first ticket:
   ```
   /start-ticket TICKET-1 feature
   ```

### Existing project (copy `.cursor/`)

```bash
cp -r cursor-agentic-template/.cursor your-project/.cursor
# Then edit your-project/.cursor/profile.json and CUSTOMIZE.md
```

---

## File map

```
profile.json          ← YOUR config (repos, ticket system, stack command)
CUSTOMIZE.md          ← Start here — the only checklist you need
TEMPLATE.md           ← Maintainer map: core vs overlay
agents/               ← YOUR specialist agents (stub: fullstack-specialist.md)
environments/         ← YOUR env cards (stub: local-dev.md)
skills/domain/        ← YOUR domain skills (empty by default)
skills/workflow/      ← CORE: do not edit unless upgrading
scripts/ticket/       ← CORE: do not edit unless upgrading
hooks/                ← CORE: do not edit unless upgrading
_shared/              ← CORE contracts: do not edit unless upgrading
```

---

## Ticket lifecycle

```
/start-ticket TICKET-42 feature   → plan → approve → build (branch mode)
/complete-task                    → verify → retrospective → ledger row
/prep-pr                          → PR description + ADO write-back
```

See `USER-MANUAL.md` for the full two-chat lifecycle and model guidance.

---

## Upgrading core

Core files (`skills/workflow/`, `scripts/ticket/`, `hooks/`, `_shared/ticket-artifacts.md`) can be
cherry-picked or copied from the template repo without touching your overlay:

```bash
# From your project .cursor folder, with template added as upstream remote:
git fetch upstream
git checkout upstream/main -- skills/workflow/ scripts/ticket/ hooks/
```

Your overlay (`profile.json`, `environments/`, `agents/`, `skills/domain/`) is never overwritten.

---

## Projects using this template

| Project | Repo | Notes |
|---|---|---|
| TMO (cursor-agentic-workspace) | https://github.com/Andres435/cursor-agentic-workspace | ADO, IIS/React stack, multi-repo |
| _(your project here)_ | — | — |
