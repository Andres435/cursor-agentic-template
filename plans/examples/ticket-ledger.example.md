> Example artifact. Real ticket files in plans/ are user-local and never committed.

# Ticket ledger

One row per closed ticket. Written by `scripts/ticket/Update-TicketLedger.ps1` at
`/complete-task` — do not hand-edit; the script owns this format.

Durable lessons live in [../closeout-index.md](../closeout-index.md); a full closeout page is written
only when a retrospective earns one. Scorecard scale 1-5 (5 = excellent). `CtxS%` is the
`/start-ticket` chat, `CtxR%` is `/review-changes`, `Ctx%` is `/complete-task`.
`/implement` is not recorded. This file is user-local (never committed).

| Tickets | Scored | Avg E | Avg C | Avg $tok | Avg CtxS% | Avg CtxR% | Avg Ctx% |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 4 | 4 | 3 | 50% | 45% | 60% |

CtxS on 1 of 1 scored branch rows. Context percents are hook-measured; ~NN was typed by the agent; a blank was not measured. Never invent one.

`Epoch` is the workflow contract a row closed under; compare rows within one epoch. Blank = before epochs were recorded.

Rated: 1a2b3c4d

| Ticket | Type | Closed | Mode | Hours | Pts | E | C | $tok | CtxS% | CtxR% | Ctx% | PR | Lanes | Epoch |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TICKET-100 | bug | 2026-01-05 | branch | 3.0 | 2 | 4 | 4 | 3 | 50 | 45 | ~60 | 10000 | f1/s1/d0 inline:d1 | 1a2b3c4d |
