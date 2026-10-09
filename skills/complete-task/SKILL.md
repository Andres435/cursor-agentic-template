---
name: complete-task
description: Chat 3. Stop/closeout — verification, review readiness, stack smoke (a Drive for UI changes), approval package, retrospective. Does not push.
keywords: complete task, closeout, verify, review readiness, stack smoke, approval package, hours, story points, ledger, retrospective
disable-model-invocation: true
icon: check-circle
color: green
---

# Complete Task

Full instructions (verification + PR readiness + retrospective): [playbooks/complete-task.md](playbooks/complete-task.md).

Read and execute that playbook now. Do not ask for confirmation before reading it.

## Quick reference

```text
/complete-task <ticket>
```

Use only when the user explicitly invokes it. Prefer a **new chat**. Skips `review-diff` when a prior
`/review-changes` stamp (**Ready** or **No change**) still matches the work in the repo, by the same check close runs (`Get-ReviewSkip.ps1`).
After approval, the retrospective closes with one call: `Close-Ticket.ps1` (stamp, hours, `report-context`, ledger row, close gate).

Records a stack smoke pass (`Set-StackSmoke.ps1` / `Get-StackSmoke.ps1`: Never tested /
Tested / Untested latest changes); it is required to close when an affected repo has profile layer
`frontend` and the change touches a `uiGlobs` file type (a user-confirmed Drive), optional otherwise. A spike with no branch and no staged
product change also skips verification, review, and PR packaging, and shows the outcome text before
any tracker write.

This command prepares the readiness summary and approval package. It does **not** submit anything
until the user approves `/prep-pr`.
