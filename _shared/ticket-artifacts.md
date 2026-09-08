---
name: ticket-artifacts
description: The one contract for per-ticket files — what each phase must produce, and the gate that verifies it. Authoritative over any prose restatement elsewhere.
keywords: artifacts, manifest, plan file, ledger, gate, Assert-TicketArtifacts, branch mode, worktree mode, scratch, plans folder
---

# Ticket Artifacts Contract

Single source of truth for the ticket-keyed files under `.cursor/plans/`. When any command,
skill, or doc appears to restate a rule from this file, **this file wins** — fix the other doc
rather than following it.

## Durable vs scratch

| Location | Holds | Committed |
|---|---|---|
| `.cursor/plans/` | Durable, ticket-keyed artifacts — the manifest and the approved plan | Yes |
| `.cursor/tmp/tickets/` | Per-ticket scratch — commit/PR-body drafts, temporary exports | No (gitignored) |

Nothing that is regenerable from ADO or from git belongs in `plans/`. If you are about to write a
one-off draft there, it goes in `tmp/tickets/`.

## Ticket mode

Every ticket runs in one of two modes, recorded as the manifest's `mode`:

- **`branch`** (default) — branches in the canonical clones under `source\repos`. Planning and
  implementation happen in **one chat**.
- **`worktree`** (`/start-ticket … --worktree`) — repos mirrored under `source\worktrees\WI<n>`,
  planning and implementation in **separate chats/windows**.

Never hardcode a path for either. Ask:

```powershell
.\.cursor\scripts\Resolve-TicketRoot.ps1 -Ticket WI<number> -Json
```

It returns `{ ticket, mode, modeSource, root, rootExists, canonicalRoot, worktreeRoot, repos[] }`.
The manifest's `mode` wins over filesystem detection, and `rootExists: false` means **stop** — do not
work in the other tree.

## Phase outputs

| Phase | Command | Must exist when the command reports success |
|---|---|---|
| `start` | [start-ticket](../commands/start-ticket.md) | `WI<n>-manifest.json` (with `mode`, non-null `startedAtUtc`, and `ticket` object), `WI<n>-<type>-plan.md` |
| `implement` | [implement](../commands/implement.md) | inputs above must already exist; no new required output |
| `close` | [complete-task](../commands/complete-task.md) | manifest close timestamp, one `WI<n>` row in `plans/ticket-ledger.md` |

`<type>` is the manifest `workType` (`bug`, `feature`, `spike`, `refactor`).

## The gate

Do not self-assess this contract in prose. Run it:

```powershell
.\.cursor\scripts\Assert-TicketArtifacts.ps1 -Ticket WI<number> -Phase start
```

- `start-ticket` runs it with `-Phase start` as its **last artifact action** before
  `Initialize-TicketRuntime.ps1` and the final message. A `FAIL` means the command is not
  finished — write the missing file, then re-run. Runtime warmup is not an artifact.
- `implement` runs it with `-Phase implement` as its **first action**. A `FAIL` stops the chat and
  reports what start-ticket skipped; it does not silently re-plan around the gap.
- Any chat that loads ticket state uses `-Phase implement` as its **load-time** gate — including
  `/complete-task`. Do **not** run `-Phase close` at chat start: the close timestamp and the ledger
  row are written *during* `complete-task`, so a load-time close gate always fails.
- `complete-task` runs `-Phase close` after the ledger row is written, before the retrospective.

Exit code `0` = pass, `1` = fail. `-Json` returns `{ phase, ticket, mode, pass, missing[], found[] }`.

## File reference

| File | Written by | Purpose |
|---|---|---|
| `WI<n>-manifest.json` | [ticket-router](../skills/workflow/ticket-router/SKILL.md) | Classification **and** session state: `mode`, `workType`, `ticket` (title/adoType/state/area/priority), `affectedRepos`, `integration`, `environmentCard`, `specialists`, `sonarRepos`, `adrIndex`, `dbChange`, `needsDacpac`, `featureFlag`, `baseBranch`, `priorFindings`, `docSet`, `parallelPlan`, `worktreeRoot`, and the session timestamps. Drives what every later chat loads. |
| `WI<n>-<type>-plan.md` | start-ticket | The approved plan. Opens with a `## Plan Digest` (structure in [ticket-plan-output.md](ticket-plan-output.md)); the `-Phase start` gate checks that heading exists, not just the file. Durable, and the only plan `implement` follows. |
| `WI<n>-feedback.md` | address-pr-comments | Compact PR + Sonar triage packet. Conditional. |
| `WI<n>-verify.json` | complete-task | Compact `verify-repo` packets. Conditional. |
| `WI<n>-review.md` | complete-task / review-changes | Compact `review-diff` output. Conditional. |
| `plans/ticket-ledger.md` | `scripts/Update-TicketLedger.ps1` | One row per closed ticket: type, close date, mode, hours, points, scorecard, context %. Shared, append-only. |
| `plans/closeout-index.md` | complete-task | One row per durable lesson. The retrieval surface for `priorFindings` ([closeout-search.md](closeout-search.md)). |
| `WI<n>-closeout.md` | complete-task | **Only when a retrospective earns a page** ([task-retrospective.md](task-retrospective.md)). Not required by any gate. |

Keep these small and durable. Summarize subagent packets into the relevant file; do not paste raw
JSON into chat.

## Session timestamps

`startedAtUtc`, `completedAtUtc`, `reopenedAtUtc`, `reclosedAtUtc`, and `timezone` live **on the
manifest**. The retired `WI<n>-session.json` is still read as a fallback so tickets started before
this change can close; nothing writes it any more. Field semantics and the hours math stay in
[session-time-tracking.md](session-time-tracking.md).

## Handoff between chats

**Branch mode** has no handoff — `/start-ticket` plans and then builds in the same chat.

**Worktree mode** ends `/start-ticket` with these lines as **chat text**, not a file. The user opens
a new Agent chat in `WI<n>.code-workspace` (folder 0 is already the ticket root) and pastes them:

```
/implement WI<number>

Approved plan: .cursor/plans/WI<number>-<type>-plan.md
Worktree: <absolute path to source\worktrees\WI<number>>
Constraint: <one precise line, or omit this line>
```

The implementation window loads the manifest, plan, and doc set itself — the paste carries a
pointer, not a copy. Do not inline the Work Plan steps, and do not tell the user to `@` or attach a
plan file (that starts a review, not a build). Cursor cannot move an agent root onto a folder holding
several independent git repos, so `move_agent_to_root` fails on every ticket root — this paste is the
only handoff. See [../environments/worktrees.md](../environments/worktrees.md).

## Rules

- Write each phase's files **as they are produced**, not batched at the end of the command.
- The manifest is written immediately after ADO intake, before branch setup or worktree
  provisioning — it carries `startedAtUtc`, so a lost manifest loses the session clock.
- Never overwrite `startedAtUtc` after the first write.
- One ledger row per ticket; a reopen updates that row in place (re-run `Update-TicketLedger.ps1`).
- Never hand-edit `plans/ticket-ledger.md` — the script owns its format.
