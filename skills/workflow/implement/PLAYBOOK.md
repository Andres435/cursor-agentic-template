---
name: implement-skill
description: Run a ticket's already-approved plan in a fresh chat. Loads the manifest, plan, and doc set from .cursor/plans/ instead of re-planning, executes the Work Plan in order, and stops for review.
keywords: implement, execute plan, worktree window, resume, grounded refinement, deviations, scoped tests
disable-model-invocation: true
---

# Implement

Executes an approved plan in a **fresh chat**. Two reasons to be here:

1. **Worktree mode** — `/start-ticket --worktree` planned elsewhere; this is the build chat.
2. **Resuming branch mode** — the `/start-ticket` chat ran out of context.

If you are in the chat that just approved the plan in branch mode, you do **not** need this
command — keep going there (`playbooks/start-ticket.md` step 9).

## Invocation

```text
/implement TICKET-42
```

## Workflow

1. **Load ticket state**
   - Run [../ticket-context-load/SKILL.md](../ticket-context-load/SKILL.md) (`implement` profile).
   - If the gate fails, stop. Do not substitute a plan of your own.

2. **Restate the plan for confirmation (short)**
   - Echo the numbered Work Plan with `[low]|[med]|[high]` tags and the current step. One block.

3. **Execute steps in order**
   - One numbered step at a time. Cross-repo order from
     [../../../_shared/cross-repo-workflow.md](../../../_shared/cross-repo-workflow.md).
   - Dispatch a manifest `specialists[]` agent when a step needs domain depth.
   - Report progress as `step N/M done`.

4. **Grounded refinement**
   - When the code contradicts the plan:
     1. Say what the plan assumed and what the code shows — one or two lines.
     2. Smallest adjustment that still meets AC.
     3. **Before** `step N/M done`, append a dated **Deviations** line on the plan file.
   - **Stop and ask** when the change would alter AC, add a repo not in `affectedRepos`,
     introduce a schema/API contract the ticket did not name, or contradict a cited ADR.
   - **Shared / framework types:** if a shared owner is clearly the better fix, AskQuestion first
     (why, blast radius, rejected local alternative). Do not implement in passing.

5. **Verify what you changed**
   - Scoped tests per [../../../_shared/test-verification.md](../../../_shared/test-verification.md).
   - Quality gates only for repos that have a key on the manifest.

6. **Stop for review**
   - Summarize to the [chat output budget](../../../_shared/severity-and-output.md#chat-output-budget).
   - Stage what should be reviewed, then `/review-changes` in a **new chat**, then `/complete-task`.
   - Do **not** record `ctxPct.start` from this command.

## Guardrails

- Do not commit, push, create PRs, or write the tracker.
- Do not run `/start-ticket` or the router.
- Do not start the local stack — the user runs `/start-stack`.
- Do not continue into closeout in this chat.
