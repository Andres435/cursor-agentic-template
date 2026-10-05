---
name: review-changes
description: Chat 2. After you stage. Reviews the staged set for merge readiness — mode selection, repo scoping, subagent fan-out, second opinion on high-risk plans, report, and the review stamp.
keywords: code review, working tree, pre-merge, staged diff, findings, verdict
disable-model-invocation: true
icon: search
color: yellow
---

# Review Changes

Review code changes before creating PRs. Read and execute
[playbooks/review-changes.md](playbooks/review-changes.md) now. Do not ask for confirmation first.

## Modes

- **Working-tree** (default) — review staged changes across workspace repos. The ticket key comes
  from the folder name or the repos' current branches (`Get-TicketFromBranch.ps1`), so branch mode
  needs no token.
- **Pre-merge** — supply a branch token (e.g. `review-changes <ticket>`) to review the three-dot
  diff vs `origin/<base>` (`profile.baseBranchDefault`). A token naming the current branch while
  changes are staged stays working-tree.

## Key steps (summary)

1. Parse the invocation for an optional branch token → select mode.
2. With a ticket key, run [ticket-context-load](../ticket-context-load/SKILL.md) (`review-changes`
   profile); scope repos from manifest `affectedRepos` and resolve paths via `Resolve-TicketRoot.ps1`.
3. Collect diffs (`git diff --staged` for working-tree; three-dot diff for pre-merge).
4. `dispatch` `review-diff` per repo for multi-repo reviews; twice (standard + deep) when the plan
   has a `[high]` step.
5. Produce the report per [../../_shared/severity-and-output.md](../../_shared/severity-and-output.md):
   scope → files → modules → findings → notes → confidence → verdict. Read `Get-StackSmoke.ps1` for
   the Confidence **Stack smoke** row; Never tested / Untested latest changes is residual risk, not
   a Blocker.
6. Stamp `reviewReady` (`Set-ReviewReady.ps1 -Verdicts`, `"No change"` for an untouched affected
   repo) and `ctxPct.review` (`Set-TicketCtxPct.ps1`). Any edit after the stamp needs a re-review.

## References

- Full steps: [playbooks/review-changes.md](playbooks/review-changes.md)
- Rule sources: [../../_shared/review-protocol.md](../../_shared/review-protocol.md)
- Severity + format: [../../_shared/severity-and-output.md](../../_shared/severity-and-output.md)
- Subagent fan-out: `_shared/subagent-functions.md`

This command does **not** commit or push. It does write `reviewReady` / `ctxPct.review` on the ticket manifest.
