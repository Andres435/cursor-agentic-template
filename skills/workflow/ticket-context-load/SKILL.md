---
name: ticket-context-load
description: Hydrate a fresh chat from a ticket's existing artifacts — mode and root, manifest, approved plan, doc set, environment card, prior findings — instead of re-fetching ADO or re-deriving scope. Use as the first step of any chat that did not itself produce that state.
keywords: context load, hydrate, fresh chat, manifest, mode, root, artifacts gate, prior findings
---

# Ticket Context Load

A new chat has **no** ticket context. Everything it needs was already computed by `/start-ticket` and
written to `.cursor/plans/`. This skill loads that state.

Without it, a fresh chat has only whatever prose the user pasted, so it re-derives scope and
re-plans. That is the failure this skill exists to prevent.

## When To Run

As the **first step** of a chat that did not produce the state itself:
[complete-task](../../commands/complete-task.md),
[address-pr-comments](../../commands/address-pr-comments.md), and
[implement](../../commands/implement.md).

**Do not run it** in `/start-ticket` — that command *produces* this state. In branch mode
`/start-ticket` also builds in the same chat, so loading there would re-read what it just wrote. That
avoided reload is the point of branch mode.

## Steps

1. **Resolve the ticket key.** `WI<number>` from the invocation. Ask only if absent and
   unrecoverable from the workspace folder name.

2. **Resolve the mode and root.** Do not assume either.

   ```powershell
   .\.cursor\scripts\Resolve-TicketRoot.ps1 -Ticket WI<number> -Json
   ```

   - **`mode: branch`** — work happens in the canonical clones under `source\repos`. That is the
     normal case, not a fallback.
   - **`mode: worktree`** — work happens under `source\worktrees\WI<number>`. In Cursor a new Agent
     chat opened in the ticket window is *already* rooted there. **Never call
     `move_agent_to_root`** — Cursor cannot set an agent root on a folder holding several independent
     git repos, so it fails on every ticket worktree. If this chat is rooted at `source\repos`
     instead, tell the user to open a new Agent chat in the `WI<number>.code-workspace` window.
     In Claude Code, `cd` to the root or use the directory-change tool — no such limitation.
   - **`rootExists: false`** — stop. Report it and let the user re-run `/start-ticket WI<number>`.
     Do not work in the other tree; a worktree ticket silently redirected into the canonical clones
     is worse than a stopped chat.

3. **Run the artifacts gate** with `-Phase implement` — for *every* calling command, closeout
   included:

   ```powershell
   .\.cursor\scripts\Assert-TicketArtifacts.ps1 -Ticket WI<number> -Phase implement
   ```

   `-Phase implement` is the load-time gate because it checks only what must already exist (manifest
   + plan). `-Phase close` checks the close timestamp and ledger row, which `/complete-task` writes
   *later in its own run* — running it here always fails.

   On `FAIL`, stop and report exactly which artifacts are missing. Offer to reconstruct them from
   what does exist. Do not proceed by inventing a plan. See
   [ticket-artifacts.md](../../_shared/ticket-artifacts.md).

4. **Read `WI<n>-manifest.json`** and treat it as the routing table:
   - `mode` — already resolved in step 2; carry it, do not re-derive.
   - `affectedRepos` — the only repos in scope; scope every `Grep`/`Glob` to the paths
     `Resolve-TicketRoot.ps1` returned (a search from the multi-repo root times out — WI21053).
   - `docSet[]` — load **only** these slices, and load each **when the step needs it**. Do not read
     other `_shared` docs.
   - `environmentCard` — load it when non-null.
   - `specialists[]` — which agents to dispatch for implementation help.
   - `priorFindings[]` — apply these; they are prior lessons already matched to this ticket.
   - `baseBranch`, `sonarRepos`, `adrIndex`, `dbChange`, `needsDacpac` — carry forward, do not
     recompute.
   - Session timestamps (`startedAtUtc` and friends) live here too — `/complete-task` reads them for
     the hours math.

5. **Read the approved plan** `WI<n>-<type>-plan.md`, including any **Deviations** section. This is
   the authority on what to build.

6. **Get title and ADO context from `manifest.ticket`.** The five minimal fields (title, adoType,
   state, area, priority) are already on the manifest from step 4. Description, repro, and
   acceptance criteria are in the approved plan from step 5. **Do not call ADO** and do not read a
   workitem JSON file — re-fetch only if the user says "refresh ADO".

7. **Confirm branch state** in each resolved repo path: on `WI<number>`, and merge
   `origin/<baseBranch>` if behind. Report; do not commit.

8. **Post one compact load line**, then continue with the calling command:

   ```text
   Loaded TICKET-42 — feature | branch | app | none | fullstack | plan: 4 steps | 0 prior findings | branch TICKET-42 (current)
   ```

## Guardrails

- Do not re-run [ticket-router](../ticket-router/SKILL.md). The manifest already exists; refresh it
  only when the user says scope changed.
- Do not re-fetch the ADO work item, and do not search the backlog or other work items.
- Do not read `plans/*-closeout.md`, `closeout-index.md`, or `ticket-ledger.md`. `priorFindings` is
  the compact answer.
- Do not dump the manifest, plan, or work item into chat. One load line.
- Do not commit, push, create PRs, or write ADO from this skill.
