---
name: task-retrospective
description: Final closeout step — asks three questions, scores the session, records one ledger row, and writes durable findings only where the user chooses to.
keywords: retrospective, closeout, scorecard, ledger, roadmap candidate, lessons, efficiency, contextualization, cost
---

# Task Retrospective

Run this as the final step of user-invoked `complete-task`, after the approval package and after any
user-approved `prep-pr` actions. Do not run automatically after implementation, verification, or
review. Nothing runs after it unless the user starts a new request.

## The shape of this step

**Ask, then act — do not write a page by default.** Every ticket used to get a 2–6 KB
`WI<n>-closeout.md`; 29 accumulated and nothing read them back. The durable value was always one
ledger row plus, occasionally, one lesson. So:

1. Score the session (three numbers).
2. Ask the three questions below.
3. Propose specific actions for whatever the answers surfaced, and let the **user** pick.
4. Write the ledger row. Write anything else only if chosen.

## 1. Score the session

Score each axis **1–5** (5 = excellent). Heuristic — Cursor does not always expose token counts.
Prefer evidence from the chat over inventing numbers.

### Efficiency (time-to-done / rework)

| Score | Meaning |
|---|---|
| 5 | One-pass solve; plan steps matched reality; little rework |
| 4 | Minor course-correction; still finished in expected slices |
| 3 | Notable rework or wrong-repo exploration that was recovered |
| 2 | Multiple failed approaches; large plan rewrite mid-flight |
| 1 | Thrash; ticket stalled or required restart |

### Contextualization (right docs, not full dump)

| Score | Meaning |
|---|---|
| 5 | Manifest `docSet` / env card / globs loaded what was needed; little irrelevant context |
| 4 | Small gap (one missing card or slice) but recovered quickly |
| 3 | Broad searching before routing; or loaded docs that were unused |
| 2 | Confused modern vs legacy paths / wrong specialist for a long stretch |
| 1 | Context thrash; repeated full-repo scans without a router |

### Cost / tokens (quota discipline)

| Score | Meaning |
|---|---|
| 5 | Plan on the top model; tasks by difficulty; subagents on the cheap tier; packets reused |
| 4 | Slight overuse (e.g. the top model on a `[low]` step) but stayed in the included bucket |
| 3 | Large parent context, repeated ticket/CI fetches, or oversized subagent prompts |
| 2 | Off-plan models used without user direction, or many redundant full-doc loads |
| 1 | Clear on-demand burn or runaway context with no discipline |

Also note the **context percentage** used by the end of the session. That number is why branch mode
and the merged chat exist — recording it per ticket turns an impression into a trend.

## 2. Ask the three questions

Ask these in chat, together, in one short block. Offer the bracketed options so answering is one
word. Do not pad them with preamble.

1. **Did the plan hold?** — steps wrong · scope missed · estimate off · nothing
2. **Any friction in the agentic flow?** — wrong route/specialist · a doc that was missing or
   unfindable · an avoidable ADO/Sonar re-fetch · a gate or script that misfired · nothing
3. **Anything durable for next time?** — an environment-card fact · a lesson for the index · a
   workflow roadmap item · nothing

Bring your own evidence to the questions rather than asking blind: if you noticed a wrong specialist
or an avoidable re-fetch during the session, say so as part of asking. The user corrects or confirms;
they should not have to remember the session for you.

## 3. Propose, then let the user choose

For each non-`nothing` answer, propose the **specific** action — named file, one-line content — and
ask which to apply. Never apply them all silently.

| Answer points at | Proposed action | Target |
|---|---|---|
| A durable technical lesson | one row: ticket · domain · one-line lesson | [../../../../plans/closeout-index.md](../../../../plans/closeout-index.md) |
| Repeating setup or a first-search target | one bullet | the matching card under [../../../../environments/](../../../../environments/) |
| A workflow/tooling improvement | one bullet (small, do-now) | [workflow-context-roadmap.md](../../../../_shared/workflow-context-roadmap.md) |
| Deferred script/CI/doc-budget work | one row in the Open table | [workflow-tech-debt.md](../../../../_shared/workflow-tech-debt.md) |
| A gate, script, or command that misfired | a fix, or a roadmap bullet if it is not small | the script/command itself |
| Something genuinely needing a page | the full closeout file (shape below) | `../plans/WI<n>-closeout.md` |

Rules that do not bend:

- **A fix that can be a check should be a check, not another sentence.** If the answer is "the agent
  forgot X", prefer a gate in `scripts/Assert-TicketArtifacts.ps1` over more prose.
- Durable only. Never put ticket-specific facts (an unstaged Web.config, an unrelated PR) into a card,
  a rule, or the index.
- Never edit rules, skills, or environment cards **beyond the one bullet the user chose**, and never
  implement a roadmap item here — those are separate, user-initiated work.

## 4. Write the ledger row (always)

One row per closed ticket, written by the script so the format cannot drift:

```powershell
.\.cursor\scripts\ticket\Update-TicketLedger.ps1 -Ticket <ticket> -Type <bug|feature|spike|refactor> `
  -Hours <n> -Points <n> -Efficiency <1-5> -Contextualization <1-5> -CostTokens <1-5> `
  -ContextPct <0-100> -Pr <number>
```

**`-ContextPct`:** check the Cursor context-window indicator (shown in the chat header when present). Copy the percentage as an integer (e.g. 67 for "67%"). If the indicator is not visible, omit `-ContextPct` — never invent or guess the number.

Re-running for the same ticket replaces its row, so a reopen updates in place. Omit any switch you
genuinely do not have — a blank cell is honest, a guessed number is not. Never hand-edit
[../../../../plans/ticket-ledger.md](../../../../plans/ticket-ledger.md); to drop a row entered by mistake, use
`Update-TicketLedger.ps1 -Ticket <ticket> -Remove`.

Then confirm the close artifacts:

```powershell
.\.cursor\scripts\ticket\Assert-TicketArtifacts.ps1 -Ticket <ticket> -Phase close
```

## Closeout file shape (only when chosen)

```markdown
---
ticket: WI<number>
closed: <YYYY-MM-DD>
type: feature | bug | spike
---

# WI<number> Closeout

## Why this ticket earned a page
<one line — what a ledger row and an index lesson could not carry>

## Ticket summary
- What was done, repos/branches/key files, tests run, PR link and ticket state

## Retrospective
- Answers to the three questions, and what was actually changed as a result

## Other findings
- Discoveries, gotchas, deferred work
```

One file per ticket. On a reopen, append `## Closeout YYYY-MM-DD (reopen)` under the existing file and
update the top-level `closed:` — never add a second front-matter block.

## Chat output

Post at most five lines — see
[severity-and-output.md](severity-and-output.md#chat-output-budget):

```text
TICKET-42 closed — Add CSV export for users; PR 99.
Scorecard E4 / C4 / $tok3 · 3 h → 2 pts · ctx 55% · ledger updated.
Added: closeout-index row (export must use streaming for large datasets).
Declined: roadmap bullet on caching.
```

If all three answers were `nothing`, that is two lines and no files beyond the ledger. Say so plainly
rather than manufacturing a finding.
