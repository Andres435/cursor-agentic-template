---
name: review-changes
description: Review working-tree or pre-merge code changes for merge readiness. Use for code reviews, PR readiness checks, branch-vs-dev reviews, Blocker/Major finding reports, and convention or SonarQube risk review.
keywords: code review, working tree, pre-merge, staged diff, findings, verdict
---

# Review Changes

Review code changes before creating PRs. Read and follow
[../.cursor/skills/workflow/review-changes/SKILL.md](../skills/workflow/review-changes/SKILL.md)
for the full implementation.

## Modes

- **Working-tree** (default) — review staged changes across workspace repos.
- **Pre-merge** — supply a branch token (e.g. `review-changes WI16096`) to review the
  three-dot diff vs `origin/dev`.

## Key steps (summary)

1. Parse the invocation for an optional branch token → select mode.
2. Scope repos from manifest `affectedRepos` or workspace root. Resolve paths via
   `Resolve-TicketRoot.ps1 -Ticket WI<n> -Json`.
3. Collect diffs (`git diff --staged` for working-tree; three-dot diff for pre-merge).
4. Fan out `review-diff` subagent per repo for large or multi-repo reviews.
5. Produce the report per [../_shared/severity-and-output.md](../_shared/severity-and-output.md):
   scope → files → modules → findings → notes → confidence → verdict.

## References

- Full steps: [../skills/workflow/review-changes/SKILL.md](../skills/workflow/review-changes/SKILL.md)
- Rule sources: [../_shared/review-protocol.md](../_shared/review-protocol.md)
- Severity + format: [../_shared/severity-and-output.md](../_shared/severity-and-output.md)
- Subagent fan-out: [../_shared/subagent-functions.md](../_shared/subagent-functions.md)

This command is **read-only** — no commit or push.
