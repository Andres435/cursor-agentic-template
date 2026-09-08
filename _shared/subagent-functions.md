---
name: subagent-functions
description: Reusable subagent "function" contracts with fixed inputs and compact outputs, so the orchestrator can fan out token-heavy read work and keep its own context small. Use when start-ticket, complete-task, review-changes, or address-pr-comments dispatch parallel work. implement.md dispatches the manifest's specialists[] directly per step instead — a different fan-out shape (per-step domain depth, not per-repo read work) — so it is not a consumer of these specific functions.
keywords: subagent functions, explore-repo, branch-setup, verify-repo, review-diff, pr-feedback-fetch, fan-out, compact return
---

# Subagent Functions

These are **agentic functions**: reusable `Task` subagent contracts with a fixed input shape and a
strict **compact** return shape. The orchestrator calls them like functions and only sees the small
result, so its own context window stays lean (the subagent burns its own window on the heavy reads).

## Why

- **Parallelism:** independent repos/areas run at the same time (see `parallelPlan` in
  [ticket-router](../skills/workflow/ticket-router/SKILL.md)).
- **Token discipline:** big diffs, ADO/Sonar/PR JSON, and broad searches are read inside the
  subagent; only the distilled packet returns.

## Calling Convention

- Dispatch with the `Task` tool using the listed `subagent_type`. Launch independent calls in a
  single batch (one message, multiple tool calls) to run them concurrently.
- **Claude Code runtime:** the `subagent_type` values below are Cursor-specific. Use the
  `Agent` tool with the translated types in
  [adapters/claude/model-usage.md](../adapters/claude/model-usage.md#subagent-function--agent-tool-mapping)
  instead.
- **Model:** always pass `model: "composer-2.5-fast"` (highest included Composer / non-charged). Do **not**
  use `inherit` for subagents when the parent is on Grok — keep fan-out on Composer. Never pick Other
  Models for subagents unless the user explicitly orders it. If a slice is too large for Composer,
  **split it** into smaller function calls rather than upsizing the model (see [model-usage.md](model-usage.md)).
- Always pass: the **ticket id**, the **resolved path** for the target repo, and the exact
  question/scope. Subagents do not see the parent conversation. Get the path from
  `.\.cursor\scripts\Resolve-TicketRoot.ps1 -Ticket WI<n> -Json` — it returns `repos[].path` for the
  ticket's mode (canonical clone in branch mode, `source/worktrees/WI<n>/<repo>` in worktree mode).
  Never construct it by hand.
- Persist returned packets to `.cursor/plans/WI<n>-*.json|md` when they will be reused later
  (see [session-time-tracking](session-time-tracking.md) neighbors); reload the packet instead of
  re-fetching.

## Global Guardrails

- **Read/implement only inside the given path.** A function never touches another ticket's worktree,
  and never a tree it was not handed — in branch mode the canonical clone *is* the given path, so the
  rule is "stay where you were sent", not "avoid `source\repos`".
- **No side effects outside the working tree.** Subagent functions never `git commit`, `git push`,
  create PRs, or write ADO. Those stay on the single human-approved orchestrator path
  (`prep-pr` / `complete-task`).
- Return the compact shape only. Do not echo full diffs, full JSON, or file dumps to the parent.

---

## `explore-repo(repo, question) -> findings`

- **subagent_type:** `explore`
- **Use:** scope analysis / "where does X live / how does Y work" in one repo or area.
- **Inputs:** `repo`, `repoPath`, `question`, optional `thoroughness` (quick | medium | very thorough).
- **Returns (compact):**
  ```
  repo: <name>
  answer: <=5 sentences
  keyFiles: [path:line, ...]         # <=8
  entryPoints: [symbol/file, ...]    # <=5
  risks: [one-liners]                # optional
  ```

## `branch-setup(repo, ticket) -> {branch, status}`

- **subagent_type:** `shell`
- **Use:** per-repo git prep during start-ticket (parallel across independent repos).
- **Inputs:** `repo`, `repoPath`, `ticket`, `baseBranch` (default `dev`).
- **Does:** `fetch origin`; resolve resume vs fresh per
  [ado-ticket-workflow](ado-ticket-workflow.md) branch rules (local `WI<n>` without `origin/WI<n>`
  => default QA-reopen: recreate from latest base, do not merge base into old lineage). Worktree
  creation itself is done by `New-TicketWorktree.ps1`; this function reports the branch decision.
- **Returns (compact):**
  ```
  repo: <name>
  branch: WI<n>
  action: created-from-dev | attached-existing | recreated-reopen | skipped-not-local
  ahead/behind: +a/-b vs origin/dev
  notes: <=2 lines (conflicts, stash, missing remote)
  ```
- **Guardrail:** never force-apply an old pre-merge stash to a recreated branch; stop and report.

## `verify-repo(repo, testFilter) -> {pass, failing, sonar}`

- **subagent_type:** `shell` (use `dotnet-specialist` guidance for .NET test entry points)
- **Use:** scoped verification per repo at closeout (parallel, read-only).
- **Inputs:** `repo`, `repoPath`, `testFilter` (nearest fixture/project), `sonarKey` (or none).
- **Does:** run the **smallest** scoped tests first per [test-verification](test-verification.md)
  using the project's test runner. Query Sonar only when `sonarKey` is set, per
  [sonar-verification](sonar-verification.md). Repos without a `sonarKey` stay `sonar: skipped`.
- **Returns (compact):**
  ```
  repo: <name>
  tests: pass | fail | not-run(reason)
  failing: [FullyQualifiedName -> one-line reason]   # <=10
  sonar: OK | ERROR(condition) | skipped(not enrolled) | skipped(no key)
  ```

## `review-diff(repo) -> findings`

- **subagent_type:** `code-reviewer` (WI17154: if the Task tool rejects that type, use `generalPurpose` with the code-reviewer prompt — do not skip the review).
- **Use:** staged-diff or pre-merge review per repo (parallel at closeout).
- **Inputs:** `repo`, `repoPath`, `mode` (staged | premerge), optional `branch`.
- **Does:** follow [../commands/review-changes.md](../commands/review-changes.md) +
  [review-protocol](review-protocol.md); staged diff is the findings source. For very large diffs,
  chunk per file/module before reviewing to avoid context blowups.
- **Returns (compact):** the standard report shape from [severity-and-output](severity-and-output.md)
  (Blocker + Major by default) ending with a `Change-set understanding` Confidence Score.

## `pr-feedback-fetch(workItem) -> triagePacket`

- **subagent_type:** `generalPurpose`
- **Use:** gather + compact PR threads and CI/quality feedback for one work item (parallel per PR).
- **Inputs:** `workItem`, optional explicit `prTargets[]`.
- **Does:** follow [pr-feedback-fetch.md](pr-feedback-fetch.md) (trimmed thread lists first;
  full thread only when needed; never dump raw JSON). Persist `.cursor/plans/<ticket>-feedback.md`.
- **Returns (compact):** the "Compact Context For Follow-Up" packet from that command (per repo/PR:
  thread id | status | file:line | ask | context; sonar gate + issues). No fixes applied.
- **Guardrail:** read-only. Never marks threads Fixed/WontFix or replies -- that stays on the
  approved path in `address-pr-comments`.
