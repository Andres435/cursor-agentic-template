---
name: architect
description: Design before code for a change that crosses a module or repo boundary, or adds a type, contract, table, or endpoint no Accepted ADR settles. Two read-only lanes on different models sketch competing designs; the winner becomes an Engineering Decisions entry and the loser its Rejected line. Use at a plan's Engineering Decisions step, for "architect this", "design this", or /architect.
keywords: architect, design, sketch, data shape, interface depth, module boundary, design lanes, red flags, Engineering Decisions, rejected alternative, ADR
icon: lightbulb
color: purple
---

# Architect

Settle the shape before code: the caller's usage, the data shape, and which module or repo owns each
piece. Adapted from pstack's architect (Lauren Tan, MIT —
[../../THIRD-PARTY-NOTICES.md](../../THIRD-PARTY-NOTICES.md)).

Part of the workflow in every chat — engineering mode is not required. The lanes always dispatch with
explicit tier models ([../../_shared/model-routing.md](../../_shared/model-routing.md#roles)).

## When

Run at a plan's Engineering Decisions step (feature, bug-fix after root cause, spike) when **both**:

1. the rubric's overall tier is deep
   ([../../_shared/model-routing.md](../../_shared/model-routing.md#difficulty-rubric)), and
2. the change crosses a module or repo boundary, or adds a type, contract, table, or endpoint shape.

Otherwise write one line in Engineering Decisions: `architect skipped: <reason>` — for example "an
Accepted ADR settles the shape" or "single-function fix". A plan with any `[high]` step fails
`Assert-TicketArtifacts -Phase start` until its Engineering Decisions carry the architect result or
that line.

It runs inside Plan mode: every lane is read-only and returns text. Nothing is written before the plan
is approved.

## Phase A — Ground

- Reuse the `explore-repo` packets the ticket already has. Do not re-dispatch them.
- When `profile.adrIndex` is set, read that index and list the decisions that constrain the shape
  ([../../_shared/adr-policy.md](../../_shared/adr-policy.md)).
- If the design moves a shared owner, read `git log --follow` on the current owner so its history is a constraint, not a guess, and ask-user before editing it.

## Phase B — Sketch

Dispatch two read-only lanes in one message: one on the **deep** tier, one on the **standard** tier,
so the two models differ. Each gets [references/design-lane-prompt.md](references/design-lane-prompt.md)
plus the problem in three to five lines, the grounding (key files, constraining ADRs, repo dependency
order), and the acceptance criteria. Each returns one candidate of at most a page, in its reply.

If the platform's adapter marks the deep tier **inline only**, dispatch only the standard lane and
write the deep candidate yourself, from the same prompt, before reading that lane's reply — the two
must stay independent. A lane that reports another model or an automatic choice is discarded, never judged
([contract rule 8](../../_shared/model-routing.md#dispatch-rules)).

## Phase C — Screen and choose

1. Screen both candidates against [references/design-red-flags.md](references/design-red-flags.md).
   Revise or reject a flagged one.
2. Compare the survivors on interface depth. Prefer the one that hides more behind a smaller surface.
3. Same shape from both → `converged`; agreement across two models is signal. Different shapes → pick
   one and name what you graft from the other.
4. Write the result as an Engineering Decisions entry
   ([../../_shared/engineering-decisions.md](../../_shared/engineering-decisions.md)):
   - **Decision** — the chosen shape and the caller's usage in one line, ending
     `(architect: converged)` or `(architect: 2 candidates)`.
   - **Why** — the constraint that decided it; cite a principle only if it changed the choice
     ([../../_shared/engineering-principles.md](../../_shared/engineering-principles.md)).
   - **Rejected** — the other candidate and why it lost.
5. The first Work Plan step for that decision scaffolds the types and signatures. Tag it by the rubric.

## Phase D — Agree

Plan approval is the checkpoint. Pushback on the shape is new grounding: re-run Phase B with it.

## Phase E — Scrap

During implementation a pattern, not one instance, means the shape is wrong: the same workaround in
unrelated places, special-case branches for unrelated edge cases, casts or optional fields that are
always set, a lock where the sketch said nothing is shared, callers needing the abstraction's internal
rules, or two Deviations of the same shape. Stop and ask. A changed decision is a new plan, not a
Deviation.
