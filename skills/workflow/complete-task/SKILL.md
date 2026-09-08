---
name: complete-task
description: Stop/closeout workflow for verification, review readiness, PR readiness, ADO note readiness, approval package, and final retrospective.
keywords: complete task, closeout, verify, review readiness, approval package, hours, story points, ledger, retrospective
disable-model-invocation: true
---

# Complete Task

Use this command only when the user explicitly invokes it, for example `/complete-task` or "run complete-task". Do not run automatically after implementation, verification, or review.

Prefer a **new chat** for this command so intake/implementation context is not still in the window.

This command prepares the readiness summary and approval package. It does not submit anything unless the user later approves `prep-pr`.

## Workflow

0. **Load ticket state**
   - Run [../ticket-context-load/SKILL.md](../ticket-context-load/SKILL.md). It
     resolves the ticket's mode and root and loads the manifest, approved plan (including any
     **Deviations**), `docSet`, and `priorFindings`.
   - Drive verification/review off the manifest's `affectedRepos` / `sonarRepos` / `parallelPlan`
     instead of scanning every repo. Reload packets under `.cursor/plans/` instead of re-fetching
     ADO/Sonar.

1. **Verification summary (parallel)**
   - For each affected repo, dispatch the `verify-repo` subagent function (see
     [../../../_shared/subagent-functions.md](../../../_shared/subagent-functions.md)) in a single batch so they
     run concurrently; each runs scoped tests (and Sonar when the repo has a key) inside that repo's
     worktree and returns a compact pass/fail packet. Repos that are not enrolled in SonarCloud
     ([../../../_shared/sonar-projects.md](../../../_shared/sonar-projects.md)) return `sonar: skipped(not enrolled)`
     — that is expected, not a failed check.
   - **Parent does not read** [../../../_shared/test-verification.md](../../../_shared/test-verification.md) or
     [../../../_shared/sonar-verification.md](../../../_shared/sonar-verification.md) — those are for the
     `verify-repo` subagent. Concatenate packets only.
   - Summarize changed behavior and affected repositories; list tests, linters, SonarQube checks,
     manual verification, and any checks that could not be run.
   - **Silent-success integration checks** before closing integration work: an empty Activity grid
     despite a set `TrackingSubmissionError` is usually a WebAPI-vs-Handlers host/config mismatch (env
     issue), not an AC failure (WI10716); and confirm Handlers DI parity (blob client, App Insights,
     email options, `Configure<...Settings>`) so submissions did not silently no-op (WI11420).

2. **Review readiness (parallel)**
   - For each affected repo, dispatch the `review-diff` subagent function (staged mode) concurrently;
     each returns a compact Blocker+Major report from its worktree's staged diff.
   - Falls back to [review-changes.md](review-changes.md) directly for a single repo.
   - Findings come from staged changes only in working-tree mode.
   - Treat unstaged and untracked files as awareness context.

3. **Confidence Score**
   - Emit or carry forward a Confidence Score from [references/confidence-score.md](references/confidence-score.md).
   - Pick the axis that matches the ticket type:
     - bug -> `Root-cause certainty`
     - feature -> `Design certainty`
     - tech spike -> `Findings certainty`
     - refactor / cross-cutting change -> `Change-set understanding`

4. **Session time and ADO readiness**
   - Follow [references/session-time-tracking.md](references/session-time-tracking.md).
   - Update the timestamps on `.cursor/plans/WI<number>-manifest.json`: set `completedAtUtc` on the first close; when `reopenedAtUtc` is set, set `reclosedAtUtc` instead and never overwrite `completedAtUtc`. (Tickets started before timestamps moved onto the manifest still carry a `WI<n>-session.json` — read it as a fallback and write the close there.) Calculate **hours** as the sum of original + reopen segments (exclude weekends, flag holidays, 8 h/day cap; idle gap between close and reopen is excluded). **Display hours** and both segments to the user; convert to story points per the table in [session-time-tracking.md](references/session-time-tracking.md) for ADO `Custom.StoryPointsActual`. Do not ask the user for hours unless the timestamps are missing.
   - Prepare commit message(s), PR title(s), PR description(s), ADO field updates, required-field gaps, and target State transition.
   - **Commit messages** summarize total work done (subject + body).
   - **Bugs:** write **root cause** to the ADO work item field (not the commit).
   - **QA notes** (`Custom.TestNotesforQA` or mapped field) go on the **ADO ticket only**.
   - **PR title** format: `WI<number>: <ADO System.Title>` (example: `WI18158: OSC Integration: Update authentication to use oauth`).
   - **PR body:** summary, changes, confidence, ADO ticket link. Use a **Deployment / ops checklist** for out-of-repo work (App Config, Key Vault, pipeline, Service Bus, manual smoke). Use a **Code checklist** for in-repo verification only. See [Commit / PR Body Exclusions](../../../_shared/ado-ticket-workflow.md#commit--pr-body-exclusions) for what never goes in commit text or the PR body.
   - If unstaged work should be reviewed or committed, ask the user to stage it or explicitly approve including it.

5. **Approval package**
   - Present the approval package only. Include:
     - Staged files to commit
     - Unstaged and untracked awareness
     - Files that would be staged if the user approves including them
     - Commit message(s) (summary only)
     - PR title(s) (`WI<number>: <ticket title>`)
     - PR description(s)
     - ADO field updates (QA notes, root cause for bugs) and required-field gaps
     - Calculated hours breakdown and converted story points (from session timestamps)
     - Target ADO State transition
     - Optional PR-to-ADO link action, if relevant
     - When `adrIndex` is set: ADRs followed (by number), and whether any drafted-but-unapproved ADR
       stub is included in the diff and still needs `ADR Reviewers`/`ADR Approvers` sign-off
       ([../../../_shared/adr-policy.md](../../../_shared/adr-policy.md)). Omit this line when no ADR is
       in play.
   - Do not commit, push, create a PR, link PRs, write ADO updates, or move ADO State.
   - Stop after presenting the approval package and wait for the user's review.
   - If the user approves submission, hand off to [prep-pr.md](prep-pr.md) in execute-approved-package mode and run only the approved actions.

6. **Task retrospective**
   - After the approval package is presented, and after any approved `prep-pr` actions finish, run [references/task-retrospective.md](references/task-retrospective.md). Copy Cursor's context-window % into `-ContextPct` when it is visible; omit if not — never invent.
   - It **asks three questions** (did the plan hold · any agentic-flow friction · anything durable), proposes specific actions for whatever the answers surface, and lets the user choose which to apply. Do not write documentation the user did not ask for: the only unconditional output is one ledger row via `Update-TicketLedger.ps1`. A `WI<number>-closeout.md` is written **only** when a finding earns a page.
   - After the ledger row is written, confirm the close artifacts:
     `.\.cursor\scripts\Assert-TicketArtifacts.ps1 -Ticket WI<number> -Phase close`.
     On `FAIL`, write the missing timestamp/row and re-run — see
     [../../../_shared/ticket-artifacts.md](../../../_shared/ticket-artifacts.md). Do not run this gate at chat
     start; the load-time gate is `-Phase implement`.
   - The retrospective is always the final step of `complete-task`. Nothing else should run after it unless the user starts a new request.

## Approval Rule

PRs are never submitted automatically. The user must explicitly approve the approval package before any `git commit`, `git push`, `gh pr create`, ADO field update, PR link, or ADO State transition runs.
