---
name: complete-task
description: Stop/closeout workflow for verification, review readiness, PR readiness, tracker notes, approval package, and final retrospective.
keywords: complete task, closeout, verify, review readiness, approval package, hours, ledger, retrospective
---

# Complete Task

Full instructions: [../skills/workflow/complete-task/PLAYBOOK.md](../skills/workflow/complete-task/PLAYBOOK.md).

Read and execute that playbook now.

## Quick reference

```text
/complete-task TICKET-42
```

Use only when the user explicitly invokes it. Prefer a **new chat**. Skips `review-diff` when a
prior `/review-changes` is still **Ready** (`Get-ReviewSkip.ps1`). Does **not** submit until
`/prep-pr`.
