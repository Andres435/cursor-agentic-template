---
name: ticket-context-load
description: Hydrate a fresh chat from a ticket's existing artifacts — mode and root, manifest, approved plan, doc set, environment card, prior findings — instead of re-fetching the tracker or re-deriving scope. Use as the first step of any chat that did not itself produce that state.
keywords: context load, hydrate, fresh chat, manifest, mode, root, artifacts gate, prior findings, load profile
---

# Ticket Context Load

A new chat has **no** ticket context. Everything it needs was already computed by `/start-ticket` and
written to `.cursor/plans/`. This skill loads that state.

Without it, a fresh chat has only whatever prose the user pasted, so it re-derives scope and
re-plans. That is the failure this skill exists to prevent.

## Load profile — caller determines depth

**`complete-task`** is a fresh closeout chat. It does **not** need the Work Plan steps, the
`docSet`, or the `environmentCard` — those were already executed. Read only:
- `<ticket>-manifest.json` (mode, repos, timestamps, `priorFindings`)
- The **Plan Digest**, **Engineering Decisions**, and **Deviations** sections of
  `<ticket>-<type>-plan.md` (skip the Work Plan steps entirely)

**`implement` and `address-pr-comments`** need the full plan and `docSet` — use the standard steps
below unchanged.

This profile is applied at step 4 and step 5 below.

## When To Run

As the **first step** of a chat that did not produce the state itself:
[complete-task](../../../commands/complete-task.md),
[address-pr-comments](../../../commands/address-pr-comments.md), and
[implement](../../../commands/implement.md).

**Do not run it** in `/start-ticket` — that command *produces* this state. In branch mode
`/start-ticket` also builds in the same chat, so loading there would re-read what it just wrote.

**Do not run it** in `/onboard` or `/doctor`.

## Steps

1. **Resolve the ticket key.** From the invocation, using `profile.ticketPrefix`. Ask only if
   absent and unrecoverable from the workspace folder name.

2. **Resolve the mode and root.** Do not assume either.

   ```powershell
   .\.cursor\scripts\Resolve-TicketRoot.ps1 -Ticket <ticket> -Json
   ```

   - **`mode: branch`** — work happens in `profile.repos[].path`. That is the normal case.
   - **`mode: worktree`** — work happens at the worktree root the script returns. In Cursor a new
     Agent chat opened in the ticket window is *already* rooted there. **Never call
     `move_agent_to_root`** on a folder of independent git repos. If this chat is in the wrong
     window, tell the user to open a new Agent chat in the ticket `.code-workspace`.
   - **`rootExists: false`** — stop. Report it and let the user re-run `/start-ticket`.

3. **Run the artifacts gate** with `-Phase implement` — for *every* calling command, closeout
   included:

   ```powershell
   .\.cursor\scripts\Assert-TicketArtifacts.ps1 -Ticket <ticket> -Phase implement
   ```

   `-Phase implement` is the load-time gate because it checks only what must already exist (manifest
   + plan). `-Phase close` checks the close timestamp and ledger row, which `/complete-task` writes
   *later in its own run* — running it here always fails.

   On `FAIL`, stop and report exactly which artifacts are missing. Offer to reconstruct them from
   what does exist. Do not proceed by inventing a plan. See
   [ticket-artifacts.md](../../../_shared/ticket-artifacts.md).

4. **Read `<ticket>-manifest.json`** and treat it as the routing table:
   - `mode` — already resolved in step 2; carry it, do not re-derive.
   - `affectedRepos` — the only repos in scope; scope every `Grep`/`Glob` to the paths
     `Resolve-TicketRoot.ps1` returned.
   - `docSet[]` — **`implement`/`address-pr-comments` only**: load each slice when the step needs it.
     **`complete-task`**: do not load `docSet` or `environmentCard`.
   - `environmentCard` — **`implement`/`address-pr-comments` only**: load when non-null.
   - `specialists[]`, `priorFindings[]`, `baseBranch`, `adrIndex` — carry forward, do not recompute.
   - Session timestamps live here too — `/complete-task` reads them for the hours math.

5. **Read the approved plan** `<ticket>-<type>-plan.md`:
   - **`implement`/`address-pr-comments`**: full plan including Work Plan steps and **Deviations**.
   - **`complete-task`**: **only** `## Plan Digest`, `## Engineering Decisions`, and
     `## Deviations`. Do **not** read the Work Plan steps.

6. **Get title and tracker context from `manifest.ticket`.** Description, repro, and AC are in
   the approved plan. **Do not re-fetch the tracker** unless the user says "refresh".

7. **Confirm branch state** in each resolved repo path: on the ticket branch, and merge
   `origin/<baseBranch>` if behind. Report; do not commit.

8. **Post one compact load line**, then continue with the calling command:

   ```text
   Loaded TICKET-42 — feature | branch | app | none | fullstack | plan: 4 steps | 0 prior findings | branch TICKET-42 (current)
   ```

## Guardrails

- Do not re-run [ticket-router](../ticket-router/SKILL.md). Refresh the manifest only when the user
  says scope changed.
- Do not re-fetch the ticket, and do not search the backlog.
- Do not read `plans/*-closeout.md`, `closeout-index.md`, or `ticket-ledger.md`. `priorFindings` is
  the compact answer.
- Do not dump the manifest or plan into chat. One load line.
- Do not commit, push, create PRs, or write the tracker from this skill.
