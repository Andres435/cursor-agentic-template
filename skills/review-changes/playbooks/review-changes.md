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

- **No token** → working-tree mode. Review ticket paths from `Select-TicketStagePaths.ps1`
  (staged, unstaged, and untracked), then stage the clean ones. The ticket key comes from the
  workspace folder name, else `.\.cursor\scripts\ticket\Get-TicketFromBranch.ps1 -Json` (the repos'
  current branches; confirm a `closed-manifest` result, ask when `ticket` is null).
- **Token is the current branch of any affected repo** → still working-tree mode, even when the
  index is empty, with that token as the ticket key. Say so in Scope: `origin/<token>` does not
  exist before `/prep-pr` pushes.
- **Token present and it is not that current branch** → pre-merge mode. Do not change the index.
  Strip leading `origin/` if present, `git fetch origin`, then
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
   .\.cursor\scripts\ticket\Resolve-TicketRoot.ps1 -Ticket <ticket> -Json
   ```

   Use each `repos[].path` from that JSON (canonical clone in branch mode, worktree path only when
   `mode` is worktree). Never construct a worktree path by hand.

3. Run every `git` command with the working directory set to that resolved path.
4. Read optional stack smoke (does not change the review target):

   ```powershell
   .\.cursor\scripts\ticket\Get-StackSmoke.ps1 -Ticket <ticket> -Json
   ```

   Use `label` / `effective` in Notes and the Confidence **Stack smoke** row. A missing stamp is
   Never tested. A `passed` stamp whose work fingerprint no longer matches is Untested latest
   changes. Do not start the stack from this command.

## Discover changes

For each selected repo (working-tree mode):

1. List paths. Do not stage yet.

   ```powershell
   .\.cursor\scripts\ticket\Select-TicketStagePaths.ps1 -RepoPath <resolved path> -Json
   ```

   `candidates` are the review target. `denied` paths (secret-shaped names, and secret-shaped
   content added by this change) are notes only:
   no findings, and never `git add`.
2. No candidates in that repo → verdict `No change`. If every selected repo has no candidates,
   stop and report. Do not stamp Ready.
3. Review `git diff HEAD -- <tracked candidates>` plus the contents of untracked candidates.
   A file is clean when no Blocker or Major cites it. Minor and Nit do not hold it.
4. After the verdict, before the stamp:
   - Clean candidate → `git add -- <path>`
   - Blocker or Major cites it → `git restore --staged -- <path>` (the working-tree edit stays)
   - Never `git add -A`, `git add .`, or a denied path.
5. **Fix loop.** A Blocker or Major ends this review, not the ticket: the verdict follows the
   [verdict rules](../../../_shared/severity-and-output.md#verdict-rules), the stamp records the
   findings, and close fails while they are open. Tell the user: fix them (in this chat or the
   build chat), then run `/review-changes` again; the new stamp replaces this one.

Pre-merge mode: diff source is the three-dot range above. Do not run the selector to change the index.

When `git blame`/`git log` surfaces historical ticket IDs, look them up read-only in the project's
ticket system. Do not write to historical tickets.

## Optimization — subagent fan-out for multi-repo reviews

- More than one repo with a review target → `dispatch` the `review-diff` subagent function
  ([../../../_shared/subagent-functions.md](../../../_shared/subagent-functions.md)) once per repo in a single batch.
  Each returns findings and a verdict only; this chat runs the one `Set-ReviewReady` (Output item 8)
  with every repo's verdict. Say so in each dispatch packet.
- **Diff-size guard**: check `git diff HEAD --stat -- <candidates>` (pre-merge: the three-dot `--stat`). Large diffs → chunk per file/module, then merge findings. The dispatch packet names those paths and says the diff is `git diff HEAD` on them plus untracked candidates, not only `--staged`.
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
4. Findings from the candidate paths (Blocker first, then Major; Minor/Nit on request). Pre-merge: the three-dot diff.
5. Notes — paths staged, paths left out (finding or deny list), ticket context. Omit if empty.
6. Confidence Score — axis: `Change-set understanding`. Include the optional **Stack smoke** row
   from `Get-StackSmoke.ps1` (Never tested / Tested / Untested latest changes / Failed / Skipped).
   **Tested** may lower Regression risk; do **not** invent a "needs a real/runtime test" finding.
   **Never tested** / **Untested latest changes** on a UI, auth, or host-bound diff stay in **Notes**
   (one line) and Regression risk — not a Blocker/Major, not a Ready-blocker. After the verdict, one
   line only when that Notes line applied: a stack smoke pass would lower risk if they want it.
7. Verdict: **Ready** | **Ready with fixes** | **Not ready** — one-line rationale
8. Stamp + occupancy (no commit/push; skip both when no ticket key resolved):

   Working-tree mode: stage and unstage (Discover step 4) so the index is the clean candidate set, then stamp.

   ```powershell
   .\.cursor\scripts\ticket\Set-ReviewReady.ps1 -Ticket <ticket> -Mode staged -Verdicts '{"Repo":"Ready"}' -Findings '{"Repo":["Major: <one line>"]}'
   .\.cursor\scripts\ticket\Set-TicketCtxPct.ps1 -Ticket <ticket> -Phase review
   ```

   `-Mode staged` for working-tree reviews; `-Mode pre-merge` for a pre-merge review
   (complete-task skips either kind while the reviewed work is unchanged). `-Verdicts` is JSON repo → verdict for every
   repo just reviewed; stamping one repo keeps the others. An affected repo with nothing to review
   gets `"No change"`. The close gate later checks the committed work still matches this stamp, so
   **any edit after the stamp needs a re-review**. `report-context`: omit `-Percent` to use the
   measured value; never estimate.
