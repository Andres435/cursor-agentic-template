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
- **Execute-approved-package mode**: use only when the user already approved the package from [../../../commands/complete-task.md](../../../commands/complete-task.md). Do not rebuild a second approval package. Re-verify staged files still match the approved package, then execute only the approved commits, pushes, PR creations, tracker writes, and state transitions.

## First: Gather Input

Before starting, ask the user for the **Ticket Number** if not already provided in this message (e.g., `WI12345`, `AB#12345`, `JIRA-123`).

For tracker items, follow `profile.ticketSystem`. Load a custom adapter only if it exists
next to `ticket-intake-generic.md`. Do not ask for hours if the manifest has session timestamps.

1. Re-fetch the active ticket before drafting commit or PR text (skip when `ticketSystem` is `none`).
2. Use the fetched title/type/state as source of truth.
3. Use **calculated hours** from [../complete-task/references/session-time-tracking.md](../complete-task/references/session-time-tracking.md).
4. Keep tracker writes scoped to this ticket id.

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
   - Reference the ticket id in the subject: `feat|fix|refactor|docs(scope): description [<ticket>]`
   - **Bugs:** root cause goes on the **ticket** (when the tracker has a field), not in the commit
   - Hours and story points belong on the ticket, not in the PR body

3. **Generate PR Descriptions** for each repo:
   - **Title:** `<ticket>: <title>`
   - **Summary:** What changed and why (2-3 sentences)
   - **Changes:** Bullet list
   - **Ticket:** link only — hours/points stay on the tracker
   - **Confidence:** carry forward the Confidence Score

4. **Tracker notes** (`profile.ticketSystem` not `none`):
   - Update only this ticket: root cause (bugs), QA notes, hours → points from session-time-tracking.
   - Skip this section when `ticketSystem` is `none`.

5. **Approval Package**:
   - Staged/unstaged/untracked, commit messages, PR titles (`<ticket>: <title>`), tracker updates, hours.
   - Wait for explicit approval.

6. **Create PR**:
   - Do not commit, push, or write the tracker without approval.
   - Before push: `git fetch origin`, merge `origin/<baseBranch>` (`profile.baseBranchDefault`).
   - After the PR exists, apply the tracker's "in review" state if the adapter defines one.
   - Do not run the retrospective from this command — that is `/complete-task`.

## Cross-Repo PR Matrix

When the ticket spans multiple repositories, include this block in the approval package:

| Repository | Branch | PR title | PR link | Depends on |
|---|---|---|---|---|
| `<repo>` | `<ticket>` | `<ticket>: <title>` | TBD | `<upstream repo or none>` |
