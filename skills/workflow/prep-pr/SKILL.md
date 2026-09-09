---
name: prep-pr
description: Prepare changed repositories for PR submission. Use when generating commit messages, PR descriptions, testing summaries, SonarQube notes, confidence summaries, or cross-repo PR references.
keywords: PR, commit message, PR description, ADO write-back, approval package, Code Review transition
disable-model-invocation: true
---

# Prepare Pull Requests

Prepare all changed repos for PR submission.

## Modes

- **Draft mode** (default): inventory changes, draft commit messages and PR descriptions, build the approval package, and wait for user approval.
- **Execute-approved-package mode**: use only when the user already approved the package from [complete-task.md](complete-task.md). Do not rebuild a second approval package. Re-verify staged files still match the approved package, then execute only the approved commits, pushes, PR creations, ADO writes, PR links, and State transitions.

## First: Gather Input

Before starting, ask the user for the **Ticket Number** if not already provided in this message (e.g., `WI12345`, `AB#12345`, `JIRA-123`).

For ADO work items, follow [../../../_shared/ado-ticket-workflow.md](../../../_shared/ado-ticket-workflow.md):

1. Re-fetch the active work item before drafting commit or PR text.
2. Use fetched ADO context as the source of truth for title, type, current State, acceptance criteria, root cause, and spike outcomes.
3. Use **calculated hours** and **story-point conversion** from [../../../_shared/session-time-tracking.md](../../../_shared/session-time-tracking.md). Do not ask the user for hours unless the manifest has no session timestamps.
4. Keep all ADO writes scoped to the active work item ID.

## Instructions

Read `.cursor/plans/WI<number>-manifest.json` (if present) and use its `affectedRepos` as the
authoritative repo list. Resolve where to run `git` — do not assume either tree:

```powershell
.\.cursor\scripts\Resolve-TicketRoot.ps1 -Ticket WI<number> -Json
```

Run every `git` command in the `repos[].path` it returns (the canonical clone in `branch` mode, the
ticket worktree in `worktree` mode). If `rootExists` is false, stop and report it.

1. **Inventory Changes**: For each affected repo with uncommitted, staged, or untracked changes:
   - Run `git status` to see all changes
   - Run `git diff --staged --stat` for staged changes
   - Run `git diff --stat` for unstaged changes
   - List staged, unstaged, and untracked files separately
   - Treat staged changes as the commit candidate; include unstaged/untracked changes as awareness notes so unrelated work is not committed accidentally

2. **Generate Commit Messages** for each repo:
   - Reference the ticket number in the subject: `feat|fix|refactor|docs(scope): description [WI<number>]`
   - Subject under 72 characters; choose type from ADO work item and actual changes
   - **Body:** summarize **total work done** across the change set (what changed and why). One cohesive summary
   - **Bugs:** root cause goes on the **ADO ticket**, not in the commit
   - **QA notes** go on the **ADO ticket** (`Custom.TestNotesforQA` or mapped field)
   - Do not include unstaged/untracked files in the commit unless the user explicitly approves staging them
   - See [Commit / PR Body Exclusions](../../../_shared/ado-ticket-workflow.md#commit--pr-body-exclusions) for the full list of what never goes in a commit or PR body

3. **Generate PR Descriptions** for each repo:
   - **Title:** `WI<number>: <ADO System.Title>` (exact format — not conventional-commit style)
   - **Summary:** What changed and why (2-3 sentences)
   - **Changes:** Bullet list of specific modifications
   - **ADO:** Ticket link only (`WI<number>`) — other ADO field values (hours, story points) belong on the work item, not here; see [Commit / PR Body Exclusions](../../../_shared/ado-ticket-workflow.md#commit--pr-body-exclusions).
   - **SonarQube:** Note any compliance considerations (optional section)
   - **Confidence:** Carry forward Overall rating from the most recent Confidence Score (see [.cursor/_shared/confidence-score.md](../../../_shared/confidence-score.md))
   - **Related PRs:** Cross-reference PRs in other repos affected by the same ticket
   - **Deployment / ops checklist** (when applicable): items outside the code diff — App Config, Key Vault, Service Bus, pipeline, DevOps handoffs, manual smoke in deployed env
   - **Code checklist** (in-repo only):
     - [ ] Unit tests added/updated
     - [ ] No SonarQube violations introduced in touched files
     - [ ] DateTime conventions followed
     - [ ] `review-changes` completed for the change set
     - [ ] Confidence Score recorded in the PR description

4. **ADO Notes And Required Fields**:
   - Before PR creation, update only the active ADO work item with fields supported by the current session:
     - **Bug:** root cause on the ticket (mapped field); QA notes on the ticket
     - **Feature:** QA notes and acceptance-criteria coverage on the ticket
     - **Spike:** outcomes, recommendation, and follow-up work on the ticket
     - **All types:** convert session or user-supplied **hours** to story points per [session-time-tracking.md](../../../_shared/session-time-tracking.md); write the converted points on the work item only. Show calculated hours in the approval package.
     - **User Story / Bug (on approved execute):** set actual story points from the conversion table; set `Custom.TestedLocally` and `Custom.TicketCompletePerAC` to **`Done`** when the user approved the package and local verification or scoped tests passed. Use `Done` (not `Yes`/`True`). Clear `Custom.Blocker` when the user confirms unblock.
   - Prefer `wit_work_item_write` (action `update`) for `Custom.TestNotesforQA` and root-cause fields; use `wit_work_item_comment_write` (action `add`) for supplemental context.
   - Run the required-field gate from [../../../_shared/ado-required-fields.md](../../../_shared/ado-required-fields.md) before any State transition.
   - Never fabricate required values. Ask the user only for fields that cannot be derived (dev/QA story points **estimates**) or when session time is unavailable (then ask for hours or story points for actual).

5. **Approval Package**:
   - Present an explicit approval package before executing any git, GitHub, or ADO write.
   - Include:
     - Staged files to commit
     - Unstaged and untracked awareness
     - Files that would be staged if the user approves including them
     - Commit message(s) (summary only)
     - PR title(s) (`WI<number>: <ticket title>`)
     - PR description(s)
     - ADO fields to update (QA notes, root cause, story points from hours conversion)
     - Calculated hours breakdown and converted story points
     - Required-field gaps
     - Target ADO State transition
     - Optional PR-to-ADO link action, if relevant
   - If unstaged work should be reviewed or committed, ask the user to stage it or explicitly approve including it before proceeding.
   - The user must explicitly approve the package before any submission happens.

6. **Create PR And Move To Code Review**:
   - Do NOT commit, push, create a PR, link a PR, update ADO, or move ADO State without explicit approval.
   - In execute-approved-package mode, skip rebuilding the approval package and execute only the approved actions.
   - **Before push / PR create in each repo:** `git fetch origin`, then merge `origin/dev` into the work branch. Resolve any conflicts and include the merge (or conflict-resolution) commit before pushing. Do not open or update a PR against a branch that is behind `origin/dev`.
   - After approval, execute only the commits, pushes, PR creations, ADO writes, PR links, and State transitions listed in the approved package.
   - After the PR is created and pushed, if the active ADO work item is **In Progress**, move it to **Code Review** using [../../../_shared/ado-ticket-workflow.md](../../../_shared/ado-ticket-workflow.md).
   - If ADO blocks the State transition because required fields are empty, report the blocking fields and leave the work item in its current State. PR creation still stands.
   - Do not run [../../../_shared/task-retrospective.md](../../../_shared/task-retrospective.md) from this command. Retrospective runs at the end of user-invoked [complete-task.md](complete-task.md).

## Cross-Repo PR Matrix

When the ticket spans multiple repositories, include this block in the approval package and PR descriptions:

| Repository | Branch | PR title | PR link | Depends on |
|---|---|---|---|---|
| `<repo>` | `WI<number>` | `WI<number>: <title>` | TBD | `<upstream repo or none>` |
