---
name: complete-task
description: Stop/closeout workflow for verification, review readiness, PR readiness, ADO note readiness, approval package, and final retrospective.
keywords: complete task, closeout, verify, review readiness, approval package, hours, story points, ledger, retrospective
---

# Complete Task

Full instructions (verification + PR readiness + retrospective): [../skills/workflow/complete-task/SKILL.md](../skills/workflow/complete-task/SKILL.md).

Read and execute that skill now. Do not ask for confirmation before reading the skill.

## Quick reference

```text
/complete-task WI22132
```

Use only when the user explicitly invokes it. Prefer a **new chat** so implementation context is not still loaded.

This command prepares the readiness summary and approval package. It does **not** submit anything until the user approves `/prep-pr`.
