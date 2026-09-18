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

Required outputs are defined once in [../_shared/ticket-artifacts.md](../_shared/ticket-artifacts.md)
and verified mechanically at step 8. Write each file at the step that produces it.

## Invocation

```text
/start-ticket <TICKET-ID> bug|feature|spike [--worktree]
```

Ask for the ticket id and work type if either is missing. Use `profile.ticketPrefix` (not a
hardcoded `WI`).

## Mode

| | **branch** (`profile.defaultMode`) | **worktree** (`--worktree`) |
|---|---|---|
| Where work happens | paths in `profile.repos[].path` | worktree root from `Resolve-TicketRoot.ps1` |
| Chats | **one** — plan then build here | plan here, build in the ticket window |
| Pick it when | one ticket at a time | a second ticket in flight, or a stack pinned to a ticket |

`--worktree` is allowed only when `profile.worktreeSupported` is true. Otherwise stay in branch
mode and say so.

Record `mode` on the manifest (step 3). Later commands call `Resolve-TicketRoot.ps1`.

**Branch mode means the profile repos are the work tree.** One ticket in flight per repo. If
another ticket branch is checked out with work on it, stop and ask before switching. Stash
tracked/staged/untracked changes with a descriptive message before any branch switch.

## Workflow

0. **Load `profile.json` (one Read).** If `id` is `customize-me` (or `displayName` is still
   `My project`), run `/onboard` and stop. Otherwise treat `repos`, `ticketSystem`, `ticketPrefix`,
   `specialists`, `stacks.startCommand`, `baseBranchDefault`, and `defaultMode` as already decided.

1. **Fetch ticket context** → `manifest.ticket` object
   - Follow [../skills/workflow/start-ticket/references/ticket-intake-generic.md](../skills/workflow/start-ticket/references/ticket-intake-generic.md)
     for `profile.ticketSystem` (`none`, `github-issues`, or a custom file next to it).
   - Retry policy: [../_shared/runtime-verify.md](../_shared/runtime-verify.md) — at most **two**
     fetches. If both fail: stop; the user re-authenticates and re-invokes. No polling.
   - **Do not persist a workitem JSON file.** Map only the minimal fields onto the manifest
     `ticket` object (written at step 3): `title`, `type`, `state`, `priority` (add `area` if the
     tracker has it). The plan (step 7) carries description / repro / AC. Re-fetch only on
     "refresh", required-field gates, and `/prep-pr` write-back.

2. **Run the ticket-start gate**
   - `none`: title + acceptance criteria present (intake already asked if missing).
   - `github-issues`: title and body non-empty.
   - Custom / ADO overlay: follow that adapter's required-field gate if the file exists; otherwise
     skip the transition and note the state.

3. **Classify the ticket** → `<ticket>-manifest.json`
   - Run [../skills/workflow/ticket-router/SKILL.md](../skills/workflow/ticket-router/SKILL.md).
   - Write the manifest **now**, before branch setup. It carries `startedAtUtc` (current UTC
     ISO-8601) and `mode`.
   - **Reopen** (manifest already has `completedAtUtc`): set `reopenedAtUtc` to now,
     `reclosedAtUtc` to `null`. Never overwrite `startedAtUtc` or `completedAtUtc`.
   - If repos or integration are still ambiguous **after** the profile list, ask once before
     provisioning. Do not ask the user to re-enter profile fields.

4. **Provision worktrees** — `--worktree` only, and only if `profile.worktreeSupported`
   - If `scripts/New-TicketWorktree.ps1` (or `scripts/worktree/`) is absent, stop and say worktrees
     are not installed in this profile.
   - This chat does not edit worktree source files. Implementation is
     [../commands/implement.md](../commands/implement.md) in the ticket window.

5. **Fan-out batch per repo (parallel) — branch setup, code search, prior ticket memory**
   - Once `affectedRepos` is known, dispatch **one batch**:
     - `branch-setup` once per affected local repo
       ([../_shared/subagent-functions.md](../_shared/subagent-functions.md)). Path from
       `Resolve-TicketRoot.ps1`. Base branch = `profile.baseBranchDefault` (often `main`).
     - `explore-repo` once per affected local repo. Question: ticket title + one AC/repro clause.
       `thoroughness: quick`. Compact return only. **Skip** when there is exactly one local repo
       **and** the ticket already names the file.
     - `Search-CloseoutMemory.ps1` once per affected repo (`-MaxResults 4`). Union; dedupe by
       ticket id; cap **8** `priorFindings`.
   - Parent checks packets. Drop empty/off-topic; keep contradictions as Engineering Decisions
     candidates. Never dump all `keyFiles` into chat.
   - **Local ticket branch exists but origin does not** (after fetch): default is a rejected or
     unmerged PR, not completion. Recreate from latest `origin/<baseBranch>`; do **not** merge
     base into the old lineage. Preserve needed work via stash/cherry-pick.
   - **Both local and remote exist:** check out, fast-forward, then merge `origin/<baseBranch>`.
   - **After `branch-setup` returns**, if `scripts/runtime/Initialize-TicketRuntime.ps1` exists,
     start it in the background while Plan mode opens. Otherwise skip — `/start-stack` is how the
     user starts the app.

6. **Draft the plan in Plan mode — do not persist yet**
   - **Switch to Plan mode automatically.** Pre-approved — do not ask to confirm the switch.
   - **Plan model:** [../_shared/model-usage.md](../_shared/model-usage.md). Claude Code:
     [../adapters/claude/model-usage.md](../adapters/claude/model-usage.md).
   - Use the `explore-repo` packets as Engineering Decisions candidates. Do **not** re-dispatch
     `explore-repo` or Grep from a multi-repo root.
   - Structure by work type: bug →
     [../skills/workflow/start-ticket/references/bug-fix.md](../skills/workflow/start-ticket/references/bug-fix.md);
     feature →
     [../skills/workflow/start-ticket/references/feature-plan.md](../skills/workflow/start-ticket/references/feature-plan.md);
     spike →
     [../skills/workflow/start-ticket/references/tech-spike.md](../skills/workflow/start-ticket/references/tech-spike.md).
   - Present the draft **in Plan mode only**. **Re-emit only the section that changed.**
   - **Never trigger Plan mode's native Build/Execute action.** Approval is a chat statement.
   - Write **Engineering Decisions** before the Work Plan
     ([../_shared/engineering-decisions.md](../_shared/engineering-decisions.md)).
     `None — <why>` is valid. An open call: AskQuestion and wait. No TBD, no "resolve during
     implement", no invented default.

7. **Persist on approval** → `<ticket>-<type>-plan.md`
   - Explicit signal ("approved", "looks good", "build it", "go"). If ambiguous, ask once.
   - Write from the **exact text just approved**
     ([../_shared/ticket-plan-output.md](../_shared/ticket-plan-output.md)).
   - This chat then builds immediately (step 9). It does **not** re-read the file to start.
     Persist anyway: `/complete-task` and overflow `/implement` are new chats.

8. **Verify the artifacts**

   ```powershell
   .\.cursor\scripts\Assert-TicketArtifacts.ps1 -Ticket <ticket> -Phase start
   ```

   `FAIL` means this command is **not finished**. If a runtime script from step 5 is still
   running, wait for it. It does **not** start the app or a browser.

9. **Branch mode: build it here.** Worktree mode: skip to step 10.
   - Follow steps 3–6 of [../skills/workflow/implement/PLAYBOOK.md](../skills/workflow/implement/PLAYBOOK.md):
     execute the Work Plan, log Deviations **before** `step N/M done`, scoped tests, stop for review.
   - Do **not** re-run the router, re-fetch the ticket, or reload state.
   - Do **not** re-Read the router, work-type template, `engineering-decisions.md`, or
     `ticket-plan-output.md`.
   - **If context runs short**, record occupancy then hand off:

     ```powershell
     .\.cursor\scripts\Set-TicketCtxPct.ps1 -Ticket <ticket> -Phase start -Percent <0-100>
     ```

     Tell the user the plan is on disk and to start `/implement <ticket>`.

10. **Final chat message** — budget in
    [../_shared/severity-and-output.md](../_shared/severity-and-output.md#chat-output-budget)
    - **Branch mode:** startup line, implementation summary, then:

      ```powershell
      .\.cursor\scripts\Set-TicketCtxPct.ps1 -Ticket <ticket> -Phase start -Percent <0-100>
      ```

      Stage what to review; `/review-changes` in a **new chat**, then `/complete-task` in another.
    - **Worktree mode:** same `Set-TicketCtxPct.ps1 -Phase start`, startup line, Work Plan, then
      the handoff paste from
      [../_shared/ticket-artifacts.md](../_shared/ticket-artifacts.md#handoff-between-chats).

## Guardrails

- Do not commit, push, create PRs, or close out from this command.
- In **worktree** mode, do not start implementation here.
- Do not persist the plan before explicit chat approval.
- Do not start the dev server, a browser, or CDP. The user runs `/start-stack`.
- Load only the manifest's `docSet`, each slice at the step that needs it.
- Subagent functions never commit, push, or write the ticket tracker.
