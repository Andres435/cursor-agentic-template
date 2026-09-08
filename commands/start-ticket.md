---
name: start-ticket
description: Start a TMO ticket from an ADO work item, classify it into a work manifest, set up branches (or per-ticket worktrees with --worktree), build the approved plan, and in branch mode implement it in the same chat.
keywords: start ticket, intake, ADO fetch, manifest, branch mode, worktree, plan mode, approval, implement
---

# Start Ticket

Full instructions (plan + branch-mode build): [../skills/workflow/start-ticket/SKILL.md](../skills/workflow/start-ticket/SKILL.md).

Read and execute that skill now. Do not ask for confirmation before reading the skill.

## Quick reference

```text
/start-ticket WI16096 bug|feature|spike [--worktree]
```

**Branch mode** (default): plan *and* build in this chat; run `/complete-task` in a new chat.
**Worktree mode** (`--worktree`): plan here, build in the ticket window via `/implement`.

Plan shapes → [references/bug-fix.md](../skills/workflow/start-ticket/references/bug-fix.md),
[references/feature-plan.md](../skills/workflow/start-ticket/references/feature-plan.md),
[references/tech-spike.md](../skills/workflow/start-ticket/references/tech-spike.md).
