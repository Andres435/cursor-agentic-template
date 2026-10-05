---
name: complete-task-skill
description: Stop/closeout workflow for verification, review readiness, PR readiness, tracker note readiness, approval package, and final retrospective.
keywords: complete task, closeout, verify, review readiness, stack smoke, approval package, hours, story points, ledger, retrospective, close gate
disable-model-invocation: true
---

# Complete Task

Use only when the user explicitly invokes `/complete-task`. Do not run automatically after
implementation, verification, or review. Prefer a **new chat** so intake/implementation context is
not still in the window.

This command prepares the readiness summary and approval package. It does not submit anything
unless the user later approves `/prep-pr`.

A **spike** (`workType` spike, `mode` investigate) with no staged product change skips steps 1 and 2:
no `verify-repo`, no `review-diff`, no commit, no PR. Still draft the findings text, show that exact
text in the approval package, and write it to the tracker (when `profile.ticketSystem` is not
`none`) only after the user approves. Session hours stay a local record; do not write them into the
spike's story-point or timebox field.

## Workflow

0. **Load ticket state**
   - Run [../../ticket-context-load/SKILL.md](../../ticket-context-load/SKILL.md) using the
     **`complete-task` load profile**: manifest plus Plan Digest, Engineering Decisions, and
     Deviations only. Do **not** load the Work Plan, `docSet`, or `environmentCard`.
   - Drive verification and review off the manifest's `affectedRepos` / `parallelPlan`, not a scan of
     every repo. Do **not** `Read` `<ticket>-verify.json` or `<ticket>-review*.md` back into the
     orchestrator — use only the compact packets the subagents return.

1. **Verification summary (parallel)**
   - **Spike:** if `mode` is `investigate` and no affected repo has staged product changes, skip.
   - `dispatch` `verify-repo` once per affected repo in a single batch
     ([../../../_shared/subagent-functions.md](../../../_shared/subagent-functions.md)); each runs
     scoped tests (and static analysis when the project has it) in its resolved path and returns a
     compact pass/fail packet. Parent concatenates packets only; do not read
     [../../../_shared/test-verification.md](../../../_shared/test-verification.md) in this chat.
   - **Write the verify receipt** — the close gate reads it. One call per returned packet:
     `.\.cursor\scripts\Set-VerifyReceipt.ps1 -Ticket <ticket> -Repo <repo> -Tests pass|fail|not-run -Sonar ok|error|not-run [-Failing <names>] [-Reason "<why not run>"]`.
     The packet's static-analysis field maps to `-Sonar` (`ok`, `error`, or `not-run` when the
     project has none or it was skipped). `not-run` tests need `-Reason` (for example docs-only).
   - Summarize changed behavior and affected repos; list tests, linters, static analysis, manual
     verification, optional stack smoke, and any checks that could not be run.
   - **Stack smoke (optional):** extra runtime confidence, not a close gate; `-Phase close` does not
     require it. Run `.\.cursor\scripts\Get-StackSmoke.ps1 -Ticket <ticket> -Json` and use
     **label** / **effective**, not raw `status`:
     - `never` — Never tested. Ask once for UI / auth / email / host-bound flows.
     - `passed` — Tested. Cite it; do not re-ask unless they want another pass.
     - `stale` — Untested latest changes (was Tested/Failed, then logic changed — PR comments, new
       commits). Ask once to re-smoke the **current** change. If the recorded status is still
       `passed`, persist `Set-StackSmoke.ps1 -Status stale` so the flag matches.
     - `failed` / `skipped` — show as Failed / Skipped.
     Pure helper/test tickets and spikes usually skip (`-Status skipped` + one-line reason). If they
     want a pass: reuse a running stack or `/start-stack`, exercise the changed flow (the user logs
     in; do not invent a harness), **ask once** whether it passed, and stamp `passed` or `failed`
     **only after they answer**. Never claim Tested without that stamp. A Failed/stale stamp is
     awareness — it does not block close unless the user says stop.

2. **Review readiness (parallel)**
   - **Spike:** same skip as step 1.
   - Run `.\.cursor\scripts\Get-ReviewSkip.ps1 -Ticket <ticket> -Json`. For each repo with
     `skip: true` (prior `/review-changes` verdict **Ready**, `-Mode staged`, fingerprint still
     matches a non-empty staged diff), **do not** dispatch `review-diff` — cite the existing review
     and the skip `reason`. `verify-repo` still always runs.
   - For each remaining repo, `dispatch` `review-diff` (staged mode) concurrently; each returns a
     compact Blocker+Major report from its resolved path's staged diff. Pass the tier; when the plan
     has a `[high]` step, add the deep-tier second opinion exactly as
     [../../review-changes/playbooks/review-changes.md](../../review-changes/playbooks/review-changes.md)
     describes. A single repo that is not skipped may use
     [../../review-changes/SKILL.md](../../review-changes/SKILL.md) directly.
   - **Stamp what this step reviewed** — the close gate needs a `reviewReady` entry per affected repo:
     `.\.cursor\scripts\Set-ReviewReady.ps1 -Ticket <ticket> -Mode staged -Verdicts '{"<repo>":"<verdict>"}'`.
     Stamping one repo keeps the others' entries. An affected repo with nothing to review gets
     `"No change"`. If the work is already committed, review the branch and stamp `-Mode pre-merge`.
     Any edit after the stamp means review again and re-stamp — close compares the committed work to it.
   - Findings come from staged changes only; unstaged and untracked files are awareness context.

3. **Confidence Score**
   - From [../references/confidence-score.md](../references/confidence-score.md), pick the axis:
     bug → `Root-cause certainty`; feature → `Design certainty`; spike → `Findings certainty`;
     refactor / cross-cutting → `Change-set understanding`.

4. **Session time and tracker readiness**
   - Follow [../references/session-time-tracking.md](../references/session-time-tracking.md).
   - Stamp `completedAtUtc` on the manifest on first close; when `reopenedAtUtc` is set, stamp
     `reclosedAtUtc` instead and never overwrite `completedAtUtc`. Display hours and both segments;
     do not ask the user for hours unless the timestamps are missing. For a spike, hours stay local.
   - Prepare commit messages, PR title/body, and tracker field updates **if**
     `profile.ticketSystem` is not `none`. PR title: `<ticket>: <title>`. Commit messages summarize
     total work done (subject + body).
   - **Bugs:** write the root cause to the tracker's root-cause field (not the commit). QA notes go
     on the **ticket only**, not the PR body.
   - **PR body:** summary, changes, confidence, ticket link. A **Deployment / ops checklist** for
     out-of-repo work; a **Code checklist** for in-repo verification only.
   - If unstaged work should be reviewed or committed, ask the user to stage it or approve including it.

5. **Approval package**
   - Present the package only. For a spike with no staged product change: the exact findings text,
     local session hours, and the tracker State question — no staged files, commit, or PR. Otherwise:
     staged files; unstaged/untracked awareness; commit message(s); PR title(s) and description(s);
     tracker updates and required-field gaps; hours and converted points; target State; **stack
     smoke (optional)** next to Review — never a close blocker, local only (keep it out of tracker QA
     notes). Add ADRs followed (by number) when [adr-policy](../../../_shared/adr-policy.md) applies.
   - Do not commit, push, create a PR, or write the tracker. Stop and wait for the user.
   - Spike approved with no product commit: write the findings and the approved State change. Do
     not hand off to prep-pr.
   - Product changes approved: hand off to [../../prep-pr/SKILL.md](../../prep-pr/SKILL.md) in
     execute-approved-package mode and run only the approved actions.

6. **Task retrospective**
   - After the approval package, and after any approved `prep-pr` actions, run
     [../references/task-retrospective.md](../references/task-retrospective.md). Record this chat's
     occupancy with `report-context` (`Set-TicketCtxPct.ps1 -Ticket <ticket> -Phase close`; omit
     `-Percent` to use the measured value), then pass `-ContextPct` to the ledger write. Never
     estimate — a blank is honest ([harness-verbs](../../../_shared/harness-verbs.md)).
   - It **asks three questions** (did the plan hold · any agentic-flow friction · anything durable),
     proposes actions for the answers, and lets the user choose. The only unconditional output is one
     ledger row via `Update-TicketLedger.ps1`; a full closeout page only when a finding earns one.
   - After the ledger row is written, confirm the close artifacts:
     `.\.cursor\scripts\Assert-TicketArtifacts.ps1 -Ticket <ticket> -Phase close`.
     On `FAIL`, write the missing timestamp/row and re-run. A missing receipt, or a review that no
     longer matches the committed work, goes back to step 1 or 2 — see
     [../../../_shared/ticket-artifacts.md](../../../_shared/ticket-artifacts.md). Do not run this
     gate at chat start; the load-time gate is `-Phase implement`.
   - The retrospective is always the final step. Nothing else runs after it unless the user starts a new request.

## Approval Rule

Nothing is submitted automatically. The user must approve the package before commit, push, PR
create, or tracker state changes.
