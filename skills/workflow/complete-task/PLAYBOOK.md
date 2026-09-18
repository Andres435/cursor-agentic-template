---
name: complete-task-skill
description: Stop/closeout workflow for verification, review readiness, PR readiness, tracker note readiness, approval package, and final retrospective.
keywords: complete task, closeout, verify, review readiness, approval package, hours, story points, ledger, retrospective
disable-model-invocation: true
---

# Complete Task

Use only when the user explicitly invokes `/complete-task`. Prefer a **new chat**.

This command prepares the readiness summary and approval package. It does not submit anything
unless the user later approves `/prep-pr`.

## Workflow

0. **Load ticket state**
   - Run [../ticket-context-load/SKILL.md](../ticket-context-load/SKILL.md) using the
     **`complete-task` load profile**: manifest plus Plan Digest, Engineering Decisions, and
     Deviations only. Do **not** load the Work Plan, `docSet`, or `environmentCard`.

1. **Verification summary (parallel)**
   - Dispatch `verify-repo` once per affected repo
     ([../../../_shared/subagent-functions.md](../../../_shared/subagent-functions.md)).
   - Parent concatenates packets only. Do not re-read test/sonar docs in this chat.

2. **Review readiness (parallel)**
   - Run `.\.cursor\scripts\Get-ReviewSkip.ps1 -Ticket <ticket> -Json`. For each repo with
     `skip: true` (prior `/review-changes` still **Ready** on the same staged fingerprint),
     **do not** dispatch `review-diff` — cite the skip `reason`. `verify-repo` still always runs.
   - For remaining repos, dispatch `review-diff` (staged). Findings from staged changes only.

3. **Confidence Score**
   - From [references/confidence-score.md](references/confidence-score.md):
     bug → root-cause; feature → design; spike → findings; otherwise change-set understanding.

4. **Session time and tracker readiness**
   - Follow [references/session-time-tracking.md](references/session-time-tracking.md).
   - Stamp `completedAtUtc` (or `reclosedAtUtc` on reopen). Display hours; do not ask unless
     timestamps are missing.
   - Prepare commit messages, PR title/body, and tracker field updates **if**
     `profile.ticketSystem` is not `none`. PR title: `<ticket>: <title>`.
   - QA notes and root cause go on the **ticket**, not the PR body, when the tracker supports them.

5. **Approval package**
   - Staged / unstaged / untracked, commit messages, PR title(s), tracker updates, hours.
   - Do not commit, push, or write the tracker. Wait for approval, then `/prep-pr`.

6. **Task retrospective**
   - Run [references/task-retrospective.md](references/task-retrospective.md).
   - **`-ContextPct` is required** on the ledger write (copy the chat occupancy; estimate if hidden).
     Also record `Set-TicketCtxPct.ps1 -Phase close`.
   - Unconditional output: one ledger row. A full closeout page only when a finding earns one.
   - Then `Assert-TicketArtifacts.ps1 -Ticket <ticket> -Phase close`.

## Approval Rule

Nothing is submitted automatically. The user must approve the package before commit, push, PR
create, or tracker state changes.
