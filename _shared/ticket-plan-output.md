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

Build the plan in the IDE's plan mode (`enter-plan`, [harness-verbs](harness-verbs.md)). Two rules:

1. **The draft is not the file.** Do not write `<ticket>-<type>-plan.md` while the user is iterating.
   Persist only once, from the exact text they approve (see
   [start-ticket.md](../skills/start-ticket/SKILL.md) step 7).
2. **Approval is a chat statement, never an IDE button.** `exit-plan` only after it
   ([harness-verbs](harness-verbs.md)); an IDE build button can run in the wrong root on worktree
   tickets. In **branch mode** the same chat continues to build after approval. In **worktree mode**
   the closing message contains a paste handoff to `/implement` in the ticket window.

### Plan model

The deep tier ([model-routing.md](model-routing.md#tiers)), mapped per IDE in
[../adapters/README.md](../adapters/README.md). When the orchestrator is not deep, a deep planner
lane drafts it ([model-routing.md](model-routing.md#planner-lane)).

### Plan structure

Use the matching skill shape: `bug-fix.md`, `feature-plan.md`, or `tech-spike.md` under
`skills/start-ticket/references/`.

Every plan needs an **Engineering Decisions** section before the Work Plan — decided, why, out of
scope, rejected; `None — <why>` is valid. Shape and gate: [engineering-decisions.md](engineering-decisions.md).

Every plan needs a numbered **Work Plan** section. Each step tagged with difficulty:

- `[low]` — renames, wiring, single-file, routine tests → fast tier
- `[med]` — multi-file slice, focused bug, one repo → standard tier
- `[high]` — tricky shared types, hard root cause, cross-cutting design → deep tier

Split a step larger than one lane can hold. `-Phase start` fails an untagged step, or a `[high]` step with no `architect` line in Engineering Decisions.

### Plan digest

The persisted plan file opens with a **Plan Digest** (before the Work Plan) so a later reader gets
the gist without reading everything.

```markdown
## Plan Digest
- **Judgment calls:** <one clause per Engineering Decisions entry — or "None">
- **Risk / blast radius:** <what could break — or "Low: <why>">
- **ADRs followed:** <cite by number when adrIndex is set — or "N/A">
- **Artifacts gate:** PASS (`scripts/Assert-TicketArtifacts.ps1 -Phase start`)
```

Four lines, not four paragraphs. **Judgment calls** summarizes Engineering Decisions; on disagreement
the section wins. Never edit the digest after approval; a changed intent is a new plan. An open
decision stops the plan — do not persist TBD ([engineering-decisions.md](engineering-decisions.md)).

### Deviations

Plans are written before code is searched, so `/implement` may refine a step. Append to a
**Deviations** section at the bottom of the plan file:

```markdown
## Deviations
- 2026-09-01 step 3: plan assumed keyed DI in the shared extensions file; registration actually
  lives in the feature module — registered there instead.
```

A deviation that changes acceptance criteria, adds an unlisted repo, or introduces a schema change
is not a refinement — stop and ask.

### Revising the draft

A plan is 5–11 KB; reprinting it each revision is the largest cost in `/start-ticket`. Quote and
revise **only** the changed step or section. Reprint the whole Work Plan at most once (on request or
at final approval).

### Final startup message template

**Branch mode** — implementation happens in this same chat, no paste block:

```markdown
## Startup — <ticket>
- Title: … | State: <state> | Mode: branch | Branch: <ticket>
- Repos: … | Manifest: `plans/<ticket>-manifest.json`

## Approved plan
<Work Plan steps with [low]|[med]|[high] tags>
<1–3 lines approach / root cause>
```

Then build it here; close with the implementation summary plus "run `/review-changes` in a new chat, then `/complete-task`" (chat counts: [USER-MANUAL.md](../USER-MANUAL.md)).

**Worktree mode** — four-backtick outer fence so the inner paste fence survives:

````markdown
## Startup — <ticket>
- Title: … | State: <state> | Mode: worktree | Branch: <ticket>
- Worktree: <absolute worktree path>
- Repos: … | Manifest: `plans/<ticket>-manifest.json`

## Approved plan
<Work Plan steps with [low]|[med]|[high] tags>
<1–3 lines approach / root cause>

## Next
1. Open a new Agent chat in the <ticket> window and paste the block below.

## Paste into the <ticket> window

```
/implement <ticket>

Approved plan: plans/<ticket>-<type>-plan.md
Worktree: <absolute worktree path>
Constraint: <one precise line, or omit this line>
```
````

Nothing after that inner fence.

### Do not

- Continue implementation in the plan-mode chat in **worktree mode** — user opens a new chat in the ticket window.
- Build the plan below the deep tier (engineering mode sends it to the deep planner lane).
- End `/start-ticket` with only a path pointer, or persist the plan file before explicit approval.
- `exit-plan`, or trigger or suggest an IDE build button, before the chat approval.
- If plan mode fails, draft in plain chat instead, get the same explicit approval, write the file.

---

## At Ticket Close

Closeout output is owned entirely by [task-retrospective.md](../skills/complete-task/references/task-retrospective.md) — the three
questions, the scorecard rubrics, the ledger row, and the shape of the rare `<ticket>-closeout.md`.

Every closed ticket leaves **one row** in
`plans/ticket-ledger.md` (user-local, written by `scripts/ticket/Update-TicketLedger.ps1`; shape in [../plans/examples/ticket-ledger.example.md](../plans/examples/ticket-ledger.example.md)),
plus whatever durable lesson the user chose to record in
[../plans/closeout-index.md](../plans/closeout-index.md). A full closeout page is the exception.

**Session scorecard**, **Retrospective**, and **Other findings** are required. Scoring rubric:
[task-retrospective.md](../skills/complete-task/references/task-retrospective.md). After writing the file, post a brief chat summary with
the path. Do not repeat the closeout in chat.
