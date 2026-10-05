---
name: cross-repo-workflow
description: Dependency order for tickets that touch more than one profile repo. Load only when affectedRepos has 2+ entries.
keywords: multi-repo, dependency order, commit order, commit discipline
---

# Cross-repo workflow

When `affectedRepos` has two or more entries, implement and commit in
`profile.dependencyOrder` (shared/libs first, apps last).

- One ticket branch name per repo (`profile.ticketPrefix` + id).
- Do not push or open PRs until `/prep-pr`.
- If a downstream repo cannot build until the upstream change exists, note that in Engineering
  Decisions rather than silently widening scope.
- Identify **all** affected repos up front; a repo discovered mid-build is a Deviation that needs
  user approval, not a silent addition.

## Commit discipline

- Each repo has its own history; commit to each separately and reference the ticket id in every commit.
- Keep the subject line under 72 characters; the body summarizes the work (no QA notes or test plan).
- Cross-reference the related PRs in the other repos in each PR description.

## When unsure which repos are affected

- Schema change: the data repo + backend consumer + frontend display.
- New API endpoint: the backend + the data repo (if new data) + the frontend consumer.
- Shared auth or library change: the library + every consuming app.
- UI-only change: identify the frontend project, then check whether an API change is also needed.

Single-repo tickets skip this file.
