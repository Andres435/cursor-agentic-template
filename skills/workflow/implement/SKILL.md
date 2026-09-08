---
name: implement
description: Run a ticket's already-approved plan in a fresh chat. Loads the manifest, plan, and doc set from .cursor/plans/ instead of re-planning, executes the Work Plan in order, and stops for review.
keywords: implement, execute plan, worktree window, resume, grounded refinement, deviations, scoped tests
disable-model-invocation: true
---

# Implement

Executes an approved plan in a **fresh chat**. There are exactly two reasons to be here:

1. **Worktree mode** — `/start-ticket --worktree` planned in one window; this is the build chat, run
   in the `WI<number>.code-workspace` window it opened.
2. **Resuming branch mode** — `/start-ticket` normally plans *and* builds in one chat. If that chat
   ran out of context or was closed, this command picks the plan back up.

If you are in the chat that just approved the plan in branch mode, you do **not** need this command —
keep going there (`start-ticket.md` step 9). Loading state you already hold is the cost branch mode
exists to avoid.

## Invocation

```text
/implement WI22132
```

Optionally followed by pointer lines (plan path, root, one constraint). Ask for the work item number
if it is missing.

## What this command is

`/start-ticket` already did ADO intake, classification, branch/worktree setup, and planning. This
command **executes** that plan. It is not a planning command and not a review command.

- You **follow** the approved Work Plan step by step.
- You **may refine** a step when the real code contradicts the plan (see Grounded refinement).
- You **do not** re-plan from scratch, re-run `/start-ticket`, or re-derive scope.

## Workflow

1. **Load ticket state**
   - Run [../ticket-context-load/SKILL.md](../ticket-context-load/SKILL.md) with
     `-Phase implement`. That resolves the ticket's mode and root, runs the artifacts gate, and loads
     the manifest, approved plan, `docSet`, environment card, and `priorFindings`.
   - In **worktree** mode under Cursor this must run in the `WI<number>.code-workspace` window, whose
     folder 0 is already the ticket root. If it was pasted into the `source\repos` chat, say so and
     stop — there is no agent-root move to fall back on
     ([../../../environments/worktrees.md](../../../environments/worktrees.md)).
   - If the gate fails, stop there. Report what is missing and offer to reconstruct it. Do not
     substitute a plan of your own.

2. **Restate the plan for confirmation (short)**
   - Echo the numbered Work Plan with its `[low]|[med]|[high]` tags and the current step you are
     starting. One block, no re-derivation, no alternatives.

3. **Execute steps in order**
   - Work one numbered step at a time. Cross-repo steps follow dependency order from
     [../../../_shared/cross-repo-workflow.md](../../../_shared/cross-repo-workflow.md) using the
     dependency order from `profile.json`.
   - Read the affected repo's own `.cursor/rules/` before editing it.
   - Dispatch a manifest `specialists[]` agent when a step needs domain depth; keep it scoped to
     the step, not the whole ticket.
   - **Model per tag** (Cursor): `[low]`/`[med]` → Auto or Composer 2.5; `[high]` → Grok 4.5.
     Claude Code: [../adapters/claude/model-usage.md](../adapters/claude/model-usage.md).
   - Report progress as `step N/M done`. Do not narrate every file read.

4. **Grounded refinement (when the plan meets reality)**
   - The plan was built from the ADO work item before the code was searched, so a step can be wrong
     about a file, a symbol, or an order. When that happens:
     1. Say what the plan assumed and what the code actually shows — one or two lines.
     2. Make the smallest adjustment that satisfies the ticket's acceptance criteria.
     3. Append a dated line to the **Deviations** section of `.cursor/plans/WI<n>-<type>-plan.md`
        (create the section if absent): `- <date> step N: <assumed> → <actual>; <what changed>`.
   - **Stop and ask instead of refining** when the change would alter acceptance criteria, add a
     repo not in `affectedRepos`, introduce a schema change when `dbChange` is false, touch C-Class
     legacy code the plan did not anticipate, or contradict an Accepted ADR the plan cited
     ([../../../_shared/adr-policy.md](../../../_shared/adr-policy.md)) — an ADR conflict is a decision for the
     user, not a code-shape refinement.
   - Silent divergence is the failure mode this section exists to prevent. Refinement is always
     visible in chat *and* in the plan file.

5. **Verify what you changed**
   - Run scoped tests per [../../../_shared/test-verification.md](../../../_shared/test-verification.md) for the
     repos you touched. Scope to the affected fixture; broad `dotnet test` from a repo root is slow
     and noisy on this workspace.
   - Sonar only for repos in the manifest's `sonarRepos`. Repos that are not
     enrolled report `skipped(not enrolled)` — that is expected, not a failure.

6. **Stop for review**
   - Summarize to the budget in
     [../../../_shared/severity-and-output.md](../../../_shared/severity-and-output.md#chat-output-budget):
     steps completed, files changed per repo, tests run and outcome, any Deviations recorded,
     anything deliberately left out.
   - Tell the user to stage what they want reviewed, then run `/complete-task` in a **separate new
     chat**.

## Guardrails

- Do not commit, push, create PRs, or write to ADO. That is `/complete-task` → `/prep-pr`.
- Do not run `/start-ticket`, the ticket router, or an ADO fetch from this command.
- Do not read `plans/*-closeout.md`; the manifest's `priorFindings` is the compact answer.
- Do not widen scope past the manifest's `affectedRepos` without asking.
- Do not start the local stack from this command — the user runs `/start-stack WI<number>` when
  they want the apps.
- Do not continue into closeout in this chat.
