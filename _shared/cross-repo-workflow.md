---
name: cross-repo-workflow
description: Dependency order for tickets that touch more than one profile repo. Load only when affectedRepos has 2+ entries.
keywords: multi-repo, dependency order, commit order
---

# Cross-repo workflow

When `affectedRepos` has two or more entries, implement and commit in
`profile.dependencyOrder` (shared/libs first, apps last).

- One ticket branch name per repo (`profile.ticketPrefix` + id).
- Do not push or open PRs until `/prep-pr`.
- If a downstream repo cannot build until the upstream change exists, note that in Engineering
  Decisions rather than silently widening scope.

Single-repo tickets skip this file.
