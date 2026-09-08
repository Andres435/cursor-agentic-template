---
name: review-changes-skill
description: Full implementation steps for /review-changes — mode selection, repo scoping via Resolve-TicketRoot, git diff steps, subagent fan-out, and output shape.
keywords: code review, working tree, pre-merge, staged diff, mode selection, repo scope, subagent fan-out
---

# Review Changes — Implementation

Called by the `review-changes` command shim. Do **not** commit or push; this skill is read-only.

## Mode selection

Parse the user's invocation for an optional **branch token** (e.g. `review-changes WI16096`).

- **No token** → working-tree mode. Diff each repo's **staged** state; unstaged/untracked are context only.
- **Token present** → pre-merge mode. Strip leading `origin/` if present, `git fetch origin`, then
  compute: `git merge-base origin/dev origin/<branch>` → `git diff --stat origin/dev...origin/<branch>`.
  If `origin/<branch>` is missing after fetch, fall back to the local branch (`git diff origin/dev...HEAD`);
  note **pre-merge fallback: local branch (remote missing)**. If no local branch either, stop and report.

## Scope — mode-aware repo selection

1. Prefer `affectedRepos` from `.cursor/plans/WI<n>-manifest.json` when present; otherwise discover repos
   under the current workspace root only.
2. Resolve each repo's path:

   ```powershell
   .\.cursor\scripts\Resolve-TicketRoot.ps1 -Ticket WI<n> -Json
   ```

   Branch mode → canonical clones under `source/repos/<repo>`.  
   Worktree mode → `source/worktrees/WI<n>/<repo>`.

3. Run every `git` command with the working directory set to that resolved path.

## Discover changes

For each selected repo (working-tree mode):

1. `git status` — find repos with modifications.
2. `git diff --staged` — review target per repo.
3. `git diff` — inspect untracked file **names** as awareness context only; no findings from unstaged.
4. No staged changes → stop and report; summarize unstaged/untracked as awareness notes.

Pre-merge mode: diff source is the three-dot range above; otherwise workflow is identical.

When `git blame`/`git log` surfaces historical work item IDs, use the read-only ADO lookup in
[../../../_shared/ado-ticket-workflow.md](../../../_shared/ado-ticket-workflow.md). Do not write to historical tickets.

## Optimization — subagent fan-out for multi-repo reviews

- More than one repo with a review target → dispatch the `review-diff` subagent function
  ([../../../_shared/subagent-functions.md](../../../_shared/subagent-functions.md)) once per repo in a single batch.
- **Diff-size guard**: check `git diff --staged --stat`. Large diffs → chunk per file/module, then merge findings.

## Output

Follow [../../../_shared/review-protocol.md](../../../_shared/review-protocol.md) for rule sources and focus areas.  
Follow [../../../_shared/severity-and-output.md](../../../_shared/severity-and-output.md) for severity vocabulary and report shape:

1. Branch / scope
2. Files changed (count + breakdown)
3. Modules touched
4. Findings from **staged** changes only (Blocker first, then Major; Minor/Nit on request)
5. Notes (unstaged awareness, ADO context) — omit if empty
6. Confidence Score — axis: `Change-set understanding`
7. Verdict: **Ready** | **Ready with fixes** | **Not ready** — one-line rationale
