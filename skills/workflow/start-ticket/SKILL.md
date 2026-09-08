---
name: start-ticket
description: Start a TMO ticket from an ADO work item, classify it into a work manifest, set up branches (or per-ticket worktrees with --worktree), build the approved plan, and in branch mode implement it in the same chat.
keywords: start ticket, intake, ADO fetch, manifest, branch mode, worktree, plan mode, approval, implement
disable-model-invocation: true
---

# Start Ticket

Starts a ticket. In **branch mode** (the default) it also **builds** it — one chat, plan through
implementation. In **worktree mode** it stops at the handoff.

Required outputs are defined once in [../../../_shared/ticket-artifacts.md](../../../_shared/ticket-artifacts.md)
and verified mechanically at step 8. Write each file at the step that produces it — not in a batch
at the end.

## Invocation

```text
/start-ticket WI16096 bug|feature|spike [--worktree]
```

Ask for the work item number and work type if either is missing. ADO type `Issue` maps to work type
`bug` (pre-release defect; identical field gates to Bug).

## Mode

| | **branch** (default) | **worktree** (`--worktree`) |
|---|---|---|
| Where work happens | canonical clones in `source\repos` | `source\worktrees\WI<n>\<repo>` |
| Chats | **one** — plan then build here | plan here, build in the ticket window |
| Pick it when | the usual case: one ticket at a time | you need a second ticket in flight, or a long-running stack pinned to a ticket |

Record the choice as the manifest's `mode` (step 3). Every later command resolves it with
`Resolve-TicketRoot.ps1` rather than assuming a path.

**Branch mode means the canonical clones are the work tree.** Consequences, all load-bearing:

- One ticket in flight per repo. If another `WI*` branch is checked out with work on it, stop and ask
  before switching — use `--worktree` for genuine parallel tickets.
- Stash tracked/staged/untracked changes with a descriptive message before any branch switch.
- `/start-stack` runs against the canonical clones. That is expected, not a fallback.

## Workflow

1. **Fetch ADO context** → `manifest.ticket` object
   - Follow only the **Intake** + **Gate** slices of [../references/ado-ticket-workflow.md](../references/ado-ticket-workflow.md).
   - ADO retry policy: [../../../_shared/runtime-verify.md](../../../_shared/runtime-verify.md) — at most **two**
     `wit_work_item` gets (one timeout retry). If both gets fail: stop; the user runs `az login` and
     re-invokes. No polling.
   - Read the ADO tool descriptor before calling it. Fetch the explicit work item ID with
     `project: "Net"`, and keep every ADO call scoped to that item.
   - **Do not persist a workitem JSON file.** Map only the five minimal fields onto the manifest
     `ticket` object (written at step 3): `title`, `adoType`, `state`, `area`, `priority`. The
     plan (step 7) carries the full description/repro/AC distillation. Re-fetch ADO only on
     "refresh ADO", required-field gates, and `/prep-pr` write-back.

2. **Run the ticket-start State gate**
   - If the work item is **Ready for Dev**, run the required-field gate from
     [../references/ado-required-fields.md](../references/ado-required-fields.md), then move
     **Ready for Dev** → **In Progress**. This transition is pre-approved by invoking this command.
   - If ADO rejects the transition for missing fields, report the blocking fields and continue.
   - If the item is already **In Progress** or later, skip the transition and note the State.

3. **Classify the ticket** → `WI<n>-manifest.json`
   - Run [../ticket-router/SKILL.md](../ticket-router/SKILL.md).
   - Write the manifest **now**, before branch setup or any provisioning. It carries `startedAtUtc`
     (current UTC ISO-8601) and `mode`, so a manifest written late loses the session clock — the
     single most-often-lost write in this command.
   - **Reopen** (manifest already has `completedAtUtc`): set `reopenedAtUtc` to now, `reclosedAtUtc`
     to `null`. Never overwrite `startedAtUtc` or `completedAtUtc`. Do not load
     [../../../_shared/session-time-tracking.md](../../../_shared/session-time-tracking.md) here — that file is
     for `/complete-task` hours math.
   - The manifest drives the rest of the session and every later chat: `mode`, `affectedRepos`,
     `integration`/`environmentCard`, `specialists`, `sonarRepos`, `adrIndex`, `dbChange`,
     `needsDacpac`, `baseBranch`, `priorFindings`, `docSet`, `parallelPlan`.
   - If repos or integration are ambiguous, ask the user before provisioning.

4. **Provision worktrees** — `--worktree` only; skip entirely in branch mode

   ```powershell
   .\.cursor\scripts\New-TicketWorktree.ps1 -Ticket WI<number> -Repos <repo1>,<repo2> -BaseBranch <baseBranch> -Title "<ADO System.Title>" -Open
   ```

   - Mirrors the repo root under `source\worktrees\WI<number>\`, adds a git worktree per repo on
     branch `WI<number>` (from `origin/<baseBranch>`), junctions the shared `.cursor`, and opens the
     ticket `.code-workspace` as its own window. See [../../../environments/worktrees.md](../../../environments/worktrees.md).
     Repos not cloned locally are skipped — note them in the startup summary.
   - **This chat stays rooted at `source\repos`** and does not edit worktree source files.
     Implementation happens in the ticket window via [implement.md](implement.md).
   - **One app stack at a time:** if this ticket will run the local stack, claim it with
     `.\.cursor\scripts\Set-ActiveStack.ps1 -Ticket WI<number>` before any launcher.

5. **Confirm branch state per repo (parallel)**
   - Dispatch `branch-setup` ([../../../_shared/subagent-functions.md](../../../_shared/subagent-functions.md))
     once per affected local repo, in a single batch. Each verifies fetch, `dev` freshness, and the
     resume-vs-fresh decision, then returns a compact status. Give each the path from
     `Resolve-TicketRoot.ps1`, not an assumed one.
   - **Local `WI<n>` exists but `origin/WI<n>` does not** (after fetch): default assumption is **QA
     rejection or a PR closed without merge**, not completion. Confirm via ADO State/discussion, then
     recreate `WI<n>` from latest `dev` — delete the stale local branch; do **not** merge
     `origin/dev` into the old lineage. Preserve needed work via stash/cherry-pick; stop and report
     if that conflicts.
   - **Both local and remote `WI<n>` exist:** check out, fast-forward from `origin/WI<n>`, then
     **merge `origin/dev`** before further work.
   - **Genuinely completed ticket** (ADO Closed/Done with a merged PR): treat the missing remote as
     post-merge cleanup and ask before starting new work.

6. **Draft the plan in Plan mode — do not persist yet**
   - **Switch to Plan mode automatically** (`SwitchMode`, `target_mode_id: plan`). Pre-approved —
     do not ask the user to confirm the switch.
   - **Plan model:** highest included — **Cursor Grok 4.5** ([../../../_shared/model-usage.md](../../../_shared/model-usage.md)).
     Remind the user briefly if Plan mode is still on Auto. In Claude Code use
     [../adapters/claude/model-usage.md](../adapters/claude/model-usage.md) instead.
   - **Optional scope seed:** default is to skip `explore-repo`. Dispatch it (read-only, compact
     return) only when the router still cannot name affected repos or integration, or when a
     `[high]` step depends on code you cannot name from the work item alone.
   - Structure by work type: bug → [bug-fix.md](bug-fix.md); feature → [feature-plan.md](feature-plan.md);
     spike → [tech-spike.md](tech-spike.md). Cross-repo or unclear scope → run
     [../domain/multi-repo-change/SKILL.md](../domain/multi-repo-change/SKILL.md) first.
   - Present the draft **in the Plan mode conversation only** — do not write
     `WI<n>-<type>-plan.md` yet. The point of Plan mode's UI is that the user reviews it there, asks
     questions, and requests changes; revise the draft in place across as many turns as that takes.
   - **Re-emit only the section that changed.** Revising a 5–11 KB plan by reprinting the whole thing
     every turn is the largest single cost in this command — larger than every doc it loads combined.
     Quote the step or section under discussion, not the plan.
   - **Never trigger Plan mode's native Build/Execute action**, and never suggest the user click it.
     Approval in this workflow is a **chat statement**, not a UI button. In worktree mode it would
     also execute in the wrong root (`source\repos`, spanning the canonical multi-repo clones).

7. **Persist on approval** → `WI<n>-<type>-plan.md`
   - Treat an explicit signal ("approved", "looks good", "build it", "go") as approval. If the
     signal is ambiguous, ask once — "Approve this plan?" — rather than guessing.
   - Write the file from the **exact text just approved**, not an earlier draft. Follow
     [../../../_shared/ticket-plan-output.md](../../../_shared/ticket-plan-output.md) for structure.
   - **This chat then builds immediately** (step 9). It does **not** re-read the file to start
     that build. Persist anyway: `/complete-task` is always a **new chat**, and a context-overflow
     `/implement WI<n>` is a new chat. Those chats load the approved steps from disk. Skipping the
     file would force them to re-plan. Deviations during the build are appended to the same file.
   - If the user requests another change **after** this step, revise, get approval again, and
     **overwrite** the file — do not leave a stale version behind.

8. **Verify the artifacts, then warm the runtime**

   ```powershell
   .\.cursor\scripts\Assert-TicketArtifacts.ps1 -Ticket WI<number> -Phase start
   .\.cursor\scripts\Initialize-TicketRuntime.ps1 -Ticket WI<number>
   ```

   `Assert-TicketArtifacts` `FAIL` means this command is **not finished**. Write the missing file
   and re-run until it passes. Do not report success in prose that the gate contradicts.

   `Initialize-TicketRuntime.ps1` is the local-ready check. It does **not** start the dev server or a
   browser.

   - **Worktree:** `New-TicketWorktree.ps1` already seeded `.npmrc` / `.env.local` / Caddyfile.
     This script confirms each worktree is on `WI<n>`, refreshes Tmo Feed + TmoNpmFeed tokens,
     `pnpm install` / `npm install` when `node_modules` is missing, and one-shot builds
     `Scripts\react\dist` when it is empty so VS can F5.
   - **Branch:** same heal against the canonical clones, plus a **branch checkout check** (step 5
     already created or merged; this confirms every affected repo is actually on `WI<n>`).

9. **Branch mode: build it here.** Worktree mode: skip to step 10.
   - Continue into implementation in this chat, following steps 3–6 of [implement.md](implement.md):
     execute the Work Plan in order, apply Grounded refinement (logging Deviations to the plan file),
     run scoped tests, then stop for review.
   - Do **not** re-run the router, re-fetch ADO, or reload state — it is all already in this chat.
     That saved reload is the point of branch mode.
   - **If context runs short**, stop cleanly rather than degrading: the approved plan is already on
     disk, so tell the user to start a fresh chat with `/implement WI<number>`. Say which step you
     reached. No new machinery — that is the same path worktree mode always uses.

10. **Final chat message** — see the budget in
    [../../../_shared/severity-and-output.md](../../../_shared/severity-and-output.md#chat-output-budget)
    - **Branch mode:** startup line, then the implementation summary from `implement.md` step 6, then
      "run `/complete-task` in a new chat".
    - **Worktree mode:** startup line, the approved Work Plan with its `[low]|[med]|[high]` tags, then
      the handoff paste block from
      [../../../_shared/ticket-artifacts.md](../../../_shared/ticket-artifacts.md#handoff-between-chats) —
      last, with nothing after the closing fence.

## Guardrails

- Do not commit, push, create PRs, or perform closeout from this command.
- In **worktree** mode, do not start implementation in this chat under any circumstance — including
  if the user clicks Plan mode's native Build action. That is `/implement` in the ticket window.
- Do not persist the plan file before the user approves it in chat. Revise the draft as many times as
  requested; write only once approval is explicit.
- Do not call broad ADO search or backlog tools, write to historical work items found in git
  history, or create/link/update unrelated work items.
- Do not start the dev server, a browser, or use CDP from this command. **Do** run
  `Initialize-TicketRuntime.ps1` after the artifact gate so dependencies are ready before
  implementation begins.
- Load only the manifest's `docSet`, and load each slice **at the step that needs it** rather than
  all of them at intake.
- `branch-setup` and `explore-repo` subagents are read-only — they never commit, push, or write ADO.
- Do not merge `origin/dev` into a stale `WI<n>` lineage when resuming a rejected ticket, and do not
  continue on an existing `WI*` branch without merging latest `origin/dev` first.
- Only one full app stack runs at a time; claim it with `Set-ActiveStack.ps1` before launching.
