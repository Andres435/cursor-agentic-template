---
name: implement
description: Run a ticket's already-approved plan in a fresh chat. Loads the manifest, plan, and doc set from .cursor/plans/ instead of re-planning, executes the Work Plan in order, and stops for review.
keywords: implement, execute plan, worktree window, resume, grounded refinement, deviations, scoped tests
---

# Implement

Full instructions (resume / worktree only): [../skills/workflow/implement/SKILL.md](../skills/workflow/implement/SKILL.md).

Read and execute that skill now. Do not ask for confirmation before reading the skill.

## Quick reference

```text
/implement WI22132
```

Use this command when:
1. **Worktree mode** — building in the `WI<n>.code-workspace` window.
2. **Resuming branch mode** — the `/start-ticket` chat ran out of context.

Do **not** use this in the chat that just approved the plan in branch mode — keep building there.
