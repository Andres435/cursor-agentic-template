---
name: start-ticket
description: Start a ticket from the project's ticket system, classify it into a work manifest, set up branches (or worktrees with --worktree), build the approved plan, and in branch mode implement it in the same chat.
keywords: start ticket, intake, manifest, branch mode, worktree, plan mode, approval, implement
disable-model-invocation: true
---

# Start Ticket

Starts a ticket. In **branch mode** (the default) it also **builds** it — one chat, plan through
implementation. In **worktree mode** it stops at the handoff.

**Fill-in-the-blanks first.** `profile.json`, `environments/local-dev.md`, and
`agents/fullstack-specialist.md` are the project's setup. If `profile.id` is still `customize-me`,
stop and run `/onboard` — do not invent repos, ticket prefixes, or a start command. After those
files are filled, this command is **automatic**: read the profile, fetch the ticket, plan, and
build. Do not re-ask for stack, layout, or specialists that the profile already names.

Required outputs are defined once in [../../../_shared/ticket-artifacts.md](../../../_shared/ticket-artifacts.md)
and verified mechanically at step 8. Write each file at the step that produces it — not in a batch
at the end.

## Invocation

```text
/start-ticket <TICKET-ID> bug|feature|spike [--worktree]
```

Ask for the ticket id and work type if either is missing. Use `profile.ticketPrefix` (not a
hardcoded prefix). A ticket-system type that names a pre-release defect maps to work type `bug`.

## Mode

Ask where the branch is created **before** step 3 writes `mode` — but only when there is a choice.

- **A spike** (invocation work type `spike`, or a fetched ticket type of spike) never asks. Record
  `mode: investigate`. Do not create or check out `<ticket>`.
- **`profile.worktreeSupported` is not true:** there is one place to work. Record `mode: branch`,
  say so, and do not ask. `--worktree` is refused with the same line.
- **Otherwise** `ask-user` ([harness-verbs](../../../_shared/harness-verbs.md)), two options: **main
  tree** (branch `<ticket>` in the clones at `profile.repos[].path`) or **worktree** (the root
  `Resolve-TicketRoot.ps1` returns). Skip the question only when this same user message already
  chooses: `--worktree`, or an explicit main tree / branch mode. `profile.defaultMode` may order the
  options; it never answers the question.

If a clone is already on another ticket branch, name that branch in the question. Do not switch it,
and do not leave this ticket's edits in that working tree.

| | **branch** (main tree) | **worktree** | **investigate** (spike) |
|---|---|---|---|
| Where work happens | paths in `profile.repos[].path` | worktree root from `Resolve-TicketRoot.ps1` | the clones as they are |
| Chats | **one** — plan then build here | plan here, build in the ticket window | **one** — read-only research |
| Pick it when | the user chose the main tree | the user chose a worktree, or passed `--worktree` | work type is spike |

Record the answer as the manifest's `mode` (step 3). Every later command resolves it with
`Resolve-TicketRoot.ps1` rather than assuming a path.

**Branch mode means the profile repos are the work tree.** One ticket in flight per repo. Another
ticket branch with work on it is why the question exists — do not switch that clone out from under
it. Stash tracked/staged/untracked changes with a descriptive message before any branch switch.

## Workflow

0. **Load `profile.json` (one Read).** If `id` is `customize-me` (or `displayName` is still
   `My project`), run `/onboard` and stop. Otherwise treat `repos`, `ticketSystem`, `ticketPrefix`,
   `specialists`, `stacks.startCommand`, `baseBranchDefault`, and `worktreeSupported` as already decided.

1. **Fetch ticket context** → `manifest.ticket` object
   - Follow [../references/ticket-intake-generic.md](../references/ticket-intake-generic.md)
     for `profile.ticketSystem` (`none`, `github-issues`, or a custom file next to it).
   - Retry policy: [../../../_shared/runtime-verify.md](../../../_shared/runtime-verify.md) — at most **two**
     fetches. If both fail: stop; the user re-authenticates and re-invokes. No polling.
   - **Do not persist a ticket JSON file.** Map only the minimal fields onto the manifest
     `ticket` object (written at step 3): `title`, `type`, `state`, `priority` (add `area` if the
     tracker has it). The plan (step 7) carries description / repro / AC. Re-fetch only on
     "refresh", required-field gates, and `/prep-pr` write-back.

2. **Run the ticket-start gate**
   - `none`: title + acceptance criteria present (intake already asked if missing).
   - `github-issues`: title and body non-empty.
   - Custom tracker overlay: follow that adapter's required-field gate if the file exists; otherwise
     skip the transition and note the state.

3. **Classify the ticket** → `<ticket>-manifest.json`
   - Run [../../ticket-router/SKILL.md](../../ticket-router/SKILL.md).
   - Write the manifest **now**, before branch setup or any provisioning. It carries `startedAtUtc`
     (current UTC ISO-8601) and `mode` (`branch`, `worktree`, or `investigate`), so a manifest
     written late loses the session clock — the most-often-lost write in this command.
   - **Reopen** (manifest already has `completedAtUtc`): set `reopenedAtUtc` to now,
     `reclosedAtUtc` to `null`. Never overwrite `startedAtUtc` or `completedAtUtc`.
   - If repos or integration are still ambiguous **after** the profile list, ask once before
     provisioning. Do not ask the user to re-enter profile fields.

4. **Provision worktrees** — worktree mode only; skip in branch mode and in `investigate` mode
   - Needs `profile.worktreeSupported`. If `scripts/New-TicketWorktree.ps1` (or `scripts/worktree/`)
     is absent, stop and say worktrees are not installed in this profile.
   - **This chat stays rooted at the workflow root** and does not edit worktree source files.
     Implementation happens in the ticket window via [../../implement/SKILL.md](../../implement/SKILL.md).

5. **Fan-out batch per repo (parallel) — branch setup, code search, prior ticket memory**
   - **Spike (`mode: investigate`):** do not dispatch `branch-setup` and do not start a runtime
     warmup. Still dispatch `explore-repo` and closeout search. Read whatever branch is already
     checked out. Do not create, check out, or delete `<ticket>`.
   - Once `affectedRepos` is known, dispatch **one batch** containing:
     - `branch-setup` once per affected local repo
       ([../../../_shared/subagent-functions.md](../../../_shared/subagent-functions.md)). Skip when
       `mode` is `investigate`. Path from `Resolve-TicketRoot.ps1`, not assumed. Base branch =
       `profile.baseBranchDefault` (often `main`). Each verifies fetch, base freshness, and the
       resume-vs-fresh decision, then returns a compact status.
     - `explore-repo` once per affected local repo. Question: ticket title + one AC/repro clause.
       `thoroughness: quick`. Compact return only (`answer` ≤5 sentences, `keyFiles` ≤8).
       **Skip** when there is exactly one local repo **and** the ticket already names the file.
     - `Search-CloseoutMemory.ps1` once per affected repo (`-MaxResults 4`), not one mashed
       multi-repo call. Plus one integration-only pass when `integration != none`. Union; dedupe by
       ticket id; cap **8** `priorFindings`.
   - **Parent checks each packet.** Drop empty/off-topic; keep contradictions (comment vs statement,
     a shared or protected type as true owner) as Engineering Decisions candidates. Never dump all
     `keyFiles` raw into chat. For closeout returns: merge, dedupe, cap 8.
   - The next two bullets apply only when `mode` is `branch` or `worktree`.
   - **Local ticket branch exists but origin does not** (after fetch): default is a rejected or
     unmerged PR, not completion. Confirm with the tracker State/discussion, then recreate from
     latest `origin/<baseBranch>` — delete the stale local branch; do **not** merge base into the old
     lineage. Preserve needed work via stash/cherry-pick; stop and report if that conflicts.
   - **Both local and remote exist:** check out, fast-forward from `origin/<ticket>`, then merge
     `origin/<baseBranch>` before further work.
   - **After `branch-setup` returns** (not in `investigate` mode), if
     `scripts/runtime/Initialize-TicketRuntime.ps1` exists, start it in the background while Plan
     mode opens. Otherwise skip — `/start-stack` is how the user starts the app. Keep
     `Assert-TicketArtifacts -Phase start` after persist (step 8) — the gate needs the plan.

6. **Draft the plan in Plan mode — do not persist yet**
   - **`enter-plan` automatically.** Pre-approved — do not ask the user to confirm the switch.
   - **Plan tier:** deep ([../../../_shared/model-routing.md](../../../_shared/model-routing.md#roles);
     models: the IDE adapter, [../../../adapters/README.md](../../../adapters/README.md)). Without
     engineering mode, remind the user once if this chat is below the deep tier. With engineering
     mode on and this chat below deep, draft through the contract's deep planner lane and relay its
     open decisions.
   - **Scope seed from step 5:** the `explore-repo` packets already returned. Use those key files
     and contradictions as Engineering Decisions candidates. Do **not** re-dispatch `explore-repo`
     or run a broad Grep from a multi-repo root.
   - **Shared owner in Engineering Decisions:** if a packet flags a shared or protected type as the
     real owner, consider fixing it there. State why it is the better fix, the blast radius, and the
     rejected local alternative. `ask-user` and wait before persisting — never default to editing it.
   - Structure by work type: bug → [../references/bug-fix.md](../references/bug-fix.md); feature →
     [../references/feature-plan.md](../references/feature-plan.md); spike →
     [../references/tech-spike.md](../references/tech-spike.md). Cross-repo or unclear scope → plan
     the dependency order with [../../../_shared/cross-repo-workflow.md](../../../_shared/cross-repo-workflow.md).
   - Present the draft **in the Plan mode conversation only** — do not write
     `<ticket>-<type>-plan.md` yet. The user reviews it there, asks questions, and requests
     changes; revise the draft in place across as many turns as that takes.
   - **Re-emit only the section that changed.** Reprinting a 5–11 KB plan every turn is the largest
     single cost in this command — larger than every doc it loads combined. Quote the step or
     section under discussion, not the plan.
   - **Do not `exit-plan` or start building before the user approves in chat.** Approval is a
     **chat statement**, never an IDE button. In worktree mode a build here would also run in the
     wrong root.
   - Write the plan's **Engineering Decisions** section before its Work Plan — what was decided,
     why, what is explicitly out of scope, what was rejected
     ([../../../_shared/engineering-decisions.md](../../../_shared/engineering-decisions.md)). The
     work-type template lists the candidates, including when architect and blast-radius run;
     `None — <why>` is valid. Any `[high]` step needs the architect result or
     `architect skipped: <reason>` there — the step 8 gate checks it.
   - If a judgment call (AC, ADR conflict, shared owner, extra repo) is still open, `ask-user` and
     wait. Do not draft TBD or "resolve during implement", and do not invent a default.
   - **Features:** follow the clarify batch in
     [../references/feature-plan.md](../references/feature-plan.md) — at most five questions in one
     turn, answers written into Engineering Decisions before the Work Plan. Immediately before
     asking for approval, print that file's consistency report (behaviors with no step, steps with
     no behavior, decisions that contradict an acceptance criterion). Do not treat the draft as
     ready while any list is still open, unless the user accepts the item as out of scope.

7. **Persist on approval** → `<ticket>-<type>-plan.md`
   - Treat an explicit signal ("approved", "looks good", "build it", "go") as approval. If the
     signal is ambiguous, ask once — "Approve this plan?" — rather than guessing.
   - Do not persist a Work Plan that contains TBD / "resolve during implement", or that invents a
     default for an open AC/ADR/shared-owner/extra-repo call — `ask-user` and wait instead.
   - **Features:** do not persist while the consistency report still has an open item. Empty lists,
     or an item the user explicitly accepted as out of scope, are the only passing states.
   - Write the file from the **exact text just approved**, not an earlier draft. Follow
     [../../../_shared/ticket-plan-output.md](../../../_shared/ticket-plan-output.md) for structure.
   - **This chat then builds immediately** (step 9). It does **not** re-read the file to start
     that build. Persist anyway: `/complete-task` is always a **new chat**, and a context-overflow
     `/implement <ticket>` is a new chat. Those chats load the approved steps from disk. Deviations
     during the build are appended to the same file.
   - If the user requests another change **after** this step, revise, get approval again, and
     **overwrite** the file — do not leave a stale version behind.

8. **Verify the artifacts** (runtime warmup already started in step 5)

   ```powershell
   .\.cursor\scripts\Assert-TicketArtifacts.ps1 -Ticket <ticket> -Phase start
   ```

   `FAIL` means this command is **not finished**. Write the missing file and re-run until it
   passes. Do not report success in prose that the gate contradicts.

   If a runtime script from step 5 is still running, wait for it now (skip in `investigate` mode).
   It does **not** start the app or a browser. In branch mode, also confirm every affected repo is
   actually on `<ticket>` (step 5 created or merged it).

9. **Branch mode: build it here.** Worktree mode: skip to step 10. **Investigate mode:** run the
   spike Work Plan in this chat as read-only research. Do not edit product code and do not check
   out a branch. Stop when the outcome text in [../references/tech-spike.md](../references/tech-spike.md)
   is ready for `/complete-task`.
   - **`exit-plan` first** (approval is already in chat). Writer lanes and inline edits do not run
     while this chat is still in plan mode. Do not report `step N/M done` until it has left plan mode.
   - Continue into implementation in this chat, following steps 3–7 of
     [../../implement/playbooks/implement.md](../../implement/playbooks/implement.md): execute the
     Work Plan in order (with engineering mode on, each step routes by its tag), apply Grounded
     refinement (logging Deviations to the plan file **before** reporting `step N/M done`), run
     scoped tests, converge against the behavior list or acceptance criteria, then stop for review.
   - Do **not** re-run the router, re-fetch the ticket, or reload state — it is all already in this
     chat. That saved reload is the point of branch mode.
   - Do **not** re-Read the router, work-type template, `engineering-decisions.md`, or
     `ticket-plan-output.md` — those were read during planning.
   - **If context runs short**, stop cleanly rather than degrading: `report-context` with
     `-Phase start` for this chat, then tell the user the approved plan is already on disk and to
     start a fresh chat with `/implement <ticket>`. Say which step you reached. That is the same
     path worktree mode always uses.

10. **Final chat message** — budget in
    [../../../_shared/severity-and-output.md](../../../_shared/severity-and-output.md#chat-output-budget)
    - **Branch mode:** startup line, then the implementation summary from `implement.md`, then
      record occupancy and lanes and point at review:

      ```powershell
      .\.cursor\scripts\Set-TicketCtxPct.ps1 -Ticket <ticket> -Phase start
      .\.cursor\scripts\Set-TicketLanes.ps1 -Ticket <ticket> -Lanes "<fN/sN/dN inline:dN, or off>"
      ```

      `report-context` takes no `-Percent`: it uses the measured value; never estimate. `-Lanes off`
      when engineering mode was not on. Otherwise count fast, standard, and deep dispatches, and how
      many deep steps ran inline (`f2/s1/d0 inline:d3`). A discarded lane that ran inline counts as
      inline.

      Then: stage what you want reviewed, run `/review-changes` in a **new chat**, then
      `/complete-task` in another new chat.
    - **Worktree mode:** same `report-context` (`-Phase start`, this plan chat only — `/implement`
      is not recorded), then startup line, the approved Work Plan with its `[low]|[med]|[high]`
      tags, then the handoff paste block from
      [../../../_shared/ticket-artifacts.md](../../../_shared/ticket-artifacts.md#handoff-between-chats) —
      last, with nothing after the closing fence.
    - **Investigate mode:** startup line, the outcome text, then `/complete-task` in a new chat.

## Guardrails

- Do not commit, push, create PRs, or close out from this command.
- In **worktree** mode, do not start implementation in this chat under any circumstance — including
  after `exit-plan` or an IDE build button. That is `/implement` in the ticket window.
- Do not persist the plan before explicit chat approval. Revise the draft as many times as
  requested; write only once approval is explicit.
- Do not call broad tracker search or backlog tools, write to historical tickets found in git
  history, or create/link/update unrelated tickets.
- Do not start the dev server, a browser, or CDP. The user runs `/start-stack`.
- Load only the manifest's `docSet`, and load each slice **at the step that needs it** rather than
  all of them at intake.
- `branch-setup` and `explore-repo` subagents are read-only — they never commit, push, or write the
  ticket tracker.
- Do not merge base into a stale ticket-branch lineage when resuming a rejected ticket, and do not
  continue on an existing ticket branch without merging latest `origin/<baseBranch>` first.
