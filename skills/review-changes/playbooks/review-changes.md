---
name: review-changes-skill
description: Full implementation steps for /review-changes — mode selection, repo scoping via Resolve-TicketRoot, git diff steps, subagent fan-out, second opinion, and output shape.
keywords: code review, working tree, pre-merge, staged diff, mode selection, repo scope, subagent fan-out, second opinion, stack smoke
disable-model-invocation: true
---

# Review Changes — Implementation

Called by the `review-changes` command shim. Do **not** commit or push. After the verdict, write the
`reviewReady` stamp and `ctxPct.review` on the manifest (allowed exception to read-only).

## Mode selection

Parse the user's invocation for an optional **branch token** (e.g. `review-changes <ticket>`).

- **No token** → working-tree mode. Diff each repo's **staged** state; unstaged/untracked are context only.
  The ticket key comes from the workspace folder name, else
  `.\.cursor\scripts\Get-TicketFromBranch.ps1 -Json` (the repos' current branches; confirm a
  `closed-manifest` result, ask when `ticket` is null).
- **Token is the current branch of any affected repo, and that repo has something staged** → still
  working-tree mode, with that token as the ticket key. Say so in Scope: the staged set is the work,
  and `origin/<token>` does not exist before `/prep-pr` pushes.
- **Token present** (any other case) → pre-merge mode. Strip leading `origin/` if present, `git fetch origin`, then
  compute: `git merge-base origin/<base> origin/<branch>` → `git diff --stat origin/<base>...origin/<branch>`
  (`<base>` = `profile.baseBranchDefault`).
  If `origin/<branch>` is missing after fetch, fall back to the local branch (`git diff origin/<base>...HEAD`);
  note **pre-merge fallback: local branch (remote missing)**. If no local branch either, stop and report.

## Scope — mode-aware repo selection

1. With a ticket key (from the token, the folder, or the branch, as above), first run
   [ticket-context-load](../../ticket-context-load/SKILL.md) with the **`review-changes` load
   profile**. Prefer its `affectedRepos`. Only with no key at all, discover repos under the
   current workspace root and skip the stamp (Output item 8).
2. Resolve each repo's path:

   ```powershell
   .\.cursor\scripts\Resolve-TicketRoot.ps1 -Ticket <ticket> -Json
   ```

   Use each `repos[].path` from that JSON (canonical clone in branch mode, worktree path only when
   `mode` is worktree). Never construct a worktree path by hand.

3. Run every `git` command with the working directory set to that resolved path.
4. Read optional stack smoke (does not change the review target):

   ```powershell
   .\.cursor\scripts\Get-StackSmoke.ps1 -Ticket <ticket> -Json
   ```

   Use `label` / `effective` in Notes and the Confidence **Stack smoke** row. A missing stamp is
   Never tested. A `passed` stamp whose work fingerprint no longer matches is Untested latest
   changes. Do not start the stack from this command.

## Discover changes

For each selected repo (working-tree mode):

1. `git status` — find repos with modifications.
2. `git diff --staged` — review target per repo.
3. `git status --porcelain` — unstaged (` M`) and untracked (`??`) file **names** as awareness
   context only; no findings from them.
4. No staged changes → stop and report; summarize unstaged/untracked as awareness notes.

Pre-merge mode: diff source is the three-dot range above; otherwise workflow is identical.

When `git blame`/`git log` surfaces historical ticket IDs, look them up read-only in the project's
ticket system. Do not write to historical tickets.

## Optimization — subagent fan-out for multi-repo reviews

- More than one repo with a review target → `dispatch` the `review-diff` subagent function
  ([../../../_shared/subagent-functions.md](../../../_shared/subagent-functions.md)) once per repo in a single batch.
  Each returns findings and a verdict only; this chat runs the one `Set-ReviewReady` (Output item 8)
  with every repo's verdict. Say so in each dispatch packet.
- **Diff-size guard**: check `git diff --staged --stat`. Large diffs → chunk per file/module, then merge findings.
- Every `review-diff` dispatch passes its tier
  ([../../../_shared/model-routing.md](../../../_shared/model-routing.md)).

## Second opinion — plans with a `[high]` step

Check without loading the plan:
`Select-String -Path .\.cursor\plans\<ticket>-*-plan.md -Pattern '\[high\]' -Quiet`. When true,
`dispatch` `review-diff` twice per repo in one batch — once on the **standard** tier, once on the
**deep** tier — even for a single repo, so two different models read the same diff. If the adapter
marks deep **inline only** (`deepLane: inline`), you are the deep reviewer: review the diff yourself
before reading the standard lane's findings. If the model cannot be told, say so once and `ask-user`
to pick a model; do not name one. Never keep a lane that reports an automatic choice or a substitute.
Merge by `file:line` and tag each finding `both` or `one`. A `both` finding stands; a `one` finding
gets your judgment before it is reported. The report shape below is unchanged.

## Output

Follow [../../../_shared/review-protocol.md](../../../_shared/review-protocol.md) for rule sources and focus areas.  
Follow [../../../_shared/severity-and-output.md](../../../_shared/severity-and-output.md) for severity vocabulary and report shape:

1. Branch / scope
2. Files changed (count + breakdown)
3. Modules touched
4. Findings from **staged** changes only (Blocker first, then Major; Minor/Nit on request)
5. Notes (unstaged awareness, ticket context) — omit if empty
6. Confidence Score — axis: `Change-set understanding`. Include the optional **Stack smoke** row
   from `Get-StackSmoke.ps1` (Never tested / Tested / Untested latest changes / Failed / Skipped).
   **Tested** may lower Regression risk; do **not** invent a "needs a real/runtime test" finding.
   **Never tested** / **Untested latest changes** on a UI, auth, or host-bound diff stay in **Notes**
   (one line) and Regression risk — not a Blocker/Major, not a Ready-blocker. After the verdict, one
   line only when that Notes line applied: a stack smoke pass would lower risk if they want it.
7. Verdict: **Ready** | **Ready with fixes** | **Not ready** — one-line rationale
8. Stamp + occupancy (no commit/push; skip both when no ticket key resolved):

   ```powershell
   .\.cursor\scripts\Set-ReviewReady.ps1 -Ticket <ticket> -Mode staged -Verdicts '{"Repo":"Ready"}' -Findings '{"Repo":["Major: <one line>"]}'
   .\.cursor\scripts\Set-TicketCtxPct.ps1 -Ticket <ticket> -Phase review
   ```

   `-Mode staged` for working-tree reviews; `-Mode pre-merge` for a pre-merge review
   (complete-task skips either kind while the reviewed work is unchanged). `-Verdicts` is JSON repo → verdict for every
   repo just reviewed; stamping one repo keeps the others. An affected repo with nothing to review
   gets `"No change"`. The close gate later checks the committed work still matches this stamp, so
   **any edit after the stamp needs a re-review**. `report-context`: omit `-Percent` to use the
   measured value; never estimate.
