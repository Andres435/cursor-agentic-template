---
name: review-changes
description: Review working-tree or pre-merge code changes for merge readiness.
keywords: code review, working tree, pre-merge, staged diff, findings, verdict
---

# Review Changes

Read and follow [../skills/workflow/review-changes/PLAYBOOK.md](../skills/workflow/review-changes/PLAYBOOK.md).

## Modes

- **Working-tree** (default) — staged changes.
- **Pre-merge** — `review-changes TICKET-42` vs `origin/<baseBranch>`.

Stamps `reviewReady` + `ctxPct.review` on the manifest. Does **not** commit or push.
