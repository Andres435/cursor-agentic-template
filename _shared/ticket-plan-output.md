---
name: ticket-plan-output
description: How a ticket plan is structured and delivered at start — plan digest, work plan, deviations, and the final startup message per mode.
keywords: plan structure, plan digest, work plan, low med high tags, deviations, startup message, handoff paste
---

# Ticket Plan and Closeout Output

**Which files each phase must produce is defined in [ticket-artifacts.md](ticket-artifacts.md).**
This file covers only *what goes inside* the plan and the closeout — structure, not the file list.
If the two ever disagree, `ticket-artifacts.md` wins.

## At Ticket Start — The Plan

Build the plan in **Cursor Plan mode** (Claude Code: plan mode). Two rules:

1. **The draft is not the file.** Do not write `WI<n>-<type>-plan.md` while the user is iterating.
   Persist only once, from the exact text they approve (see
   [start-ticket.md](../commands/start-ticket.md) step 7).
2. **Approval is a chat statement, never Plan mode's native Build action.** Clicking Build runs in
   the wrong root on worktree tickets. In **branch mode** the same chat continues to build after
   approval. In **worktree mode** the closing message contains a paste handoff to `/implement`.

### Plan model

Highest included Cursor model — **Grok 4.5** (see [model-usage.md](model-usage.md)).
Claude Code: [../adapters/claude/model-usage.md](../adapters/claude/model-usage.md).

### Plan structure

Use the matching work-type shape (`bug-fix`, `feature-plan`, or `tech-spike` under
`skills/workflow/start-ticket/references/`). Those files point up at this contract.

Every plan needs an **Engineering Decisions** section before the Work Plan — decided, why, out of
scope, rejected; `None — <why>` is valid. Shape and gate: [engineering-decisions.md](engineering-decisions.md).

Every plan needs a numbered **Work Plan** section. Each step tagged with difficulty:

- `[low]` — renames, wiring, single-file, routine tests → Auto / Composer
- `[med]` — multi-file slice, focused bug, one repo → Auto (Grok only if stuck)
- `[high]` — tricky shared/legacy types, hard root cause, cross-cutting design → Grok 4.5

Split a step that is larger than one Composer subagent can hold. Do not leave steps untagged.

### Plan digest

The persisted plan file opens with a **Plan Digest** (before the Work Plan) so a later reader gets
the gist without reading everything.

```markdown
## Plan Digest
- **Judgment calls:** <one clause per Engineering Decisions entry — or "None">
- **Risk / blast radius:** <what could break — or "Low: <why>">
- **ADRs followed:** <cite by number when adrIndex is set — or "N/A">
- **Artifacts gate:** PASS (`Assert-TicketArtifacts.ps1 -Phase start`)
```

Four lines, not four paragraphs. **Judgment calls** summarizes Engineering Decisions; if they
disagree, the section wins. An open decision stops the plan — do not persist TBD
([engineering-decisions.md](engineering-decisions.md)).

### Deviations

Plans are written before code is searched, so `/implement` may refine a step. Append to a
**Deviations** section at the bottom of the plan file:

```markdown
## Deviations
- 2026-09-01 step 3: plan assumed keyed DI in ServiceCollectionExtensions; registration actually
  lives in OscModule.cs — registered there instead.
```

A deviation that changes acceptance criteria, adds an unlisted repo, or introduces a schema change
is not a refinement — stop and ask.

### Revising the draft

A plan is 5–11 KB. Reprinting it on every revision turn is the single largest cost in `/start-ticket`.
Quote and revise **only** the changed step or section. Reprint the whole Work Plan at most once,
when the user asks for it or at final approval.

### Final startup message template

**Branch mode** — implementation happens in this same chat, no paste block:

```markdown
## Startup — WI<number>
- Title: … | ADO: <state> | Mode: branch | Branch: WI<number>
- Repos: … | Manifest: `.cursor/plans/WI<number>-manifest.json`

## Approved plan
<Work Plan steps with [low]|[med]|[high] tags>
<1–3 lines approach / root cause>
```

Then build it here; close with the implementation summary plus "run `/complete-task` in a new chat".

**Worktree mode** — four-backtick outer fence so the inner paste fence survives:

````markdown
## Startup — WI<number>
- Title: … | ADO: <state> | Mode: worktree | Branch: WI<number>
- Worktree: …\source\worktrees\WI<number>
- Repos: … | Manifest: `.cursor/plans/WI<number>-manifest.json`

## Approved plan
<Work Plan steps with [low]|[med]|[high] tags>
<1–3 lines approach / root cause>

## Next
1. Open a new Agent chat in the WI<number> window and paste the block below.

## Paste into the WI<number> window

```
/implement WI<number>

Approved plan: .cursor/plans/WI<number>-<type>-plan.md
Worktree: <absolute path to source\worktrees\WI<number>>
Constraint: <one precise line, or omit this line>
```
````

Nothing after that inner fence.

### Do not

- End `/start-ticket` with only a path pointer and no Work Plan in chat.
- Continue implementation in Plan-mode chat in **worktree mode** — user opens a new chat in the ticket window.
- Build the plan on a weaker model when Grok 4.5 is available.
- Persist the plan file before explicit approval.
- Trigger or suggest Plan mode's native Build/Execute action.
- If Plan mode fails, draft in plain chat instead, get the same explicit approval, write the file.

---

## At Ticket Close

Closeout output is owned entirely by [task-retrospective.md](task-retrospective.md) — the three
questions, the scorecard rubrics, the ledger row, and the shape of the rare `WI<n>-closeout.md`.

Every closed ticket leaves **one row** in
[../plans/ticket-ledger.md](../plans/ticket-ledger.md) (written by `scripts/Update-TicketLedger.ps1`),
plus whatever durable lesson the user chose to record in
[../plans/closeout-index.md](../plans/closeout-index.md). A full closeout page is the exception.

**Session scorecard**, **Retrospective**, and **Other findings** are required. Scoring rubric:
[task-retrospective.md](task-retrospective.md). After writing the file, post a brief chat summary with
the path. Do not repeat the closeout in chat.
