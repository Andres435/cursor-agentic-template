---
name: blast-radius
description: Find what a change could break beyond its diff, and prove the one fact it is safe because of by running real code. Use before changing a shared module, schema, public API or DTO, or shared config; and for "what could this break" and "blast radius of X".
keywords: blast radius, what could this break, shared owner, safety fact, proof ladder, callers, dynamic binding, risk
icon: zap
color: red
---

# Blast Radius

Listing callers is not the job — grep does that in seconds. The job is the breakage grep will not
show, and proof of the one fact the change is safe because of. Adapted from pstack's blast-radius
(Lauren Tan, MIT — [../../THIRD-PARTY-NOTICES.md](../../THIRD-PARTY-NOTICES.md)).

Part of the workflow in every chat. Tier: deep
([../../_shared/model-routing.md](../../_shared/model-routing.md)). When the adapter marks deep
**inline only**, this chat's selected model is the deep tier: do the work here. If the model cannot
be told, `ask-user` to pick a model and wait. Do not name one. Never accept a lane that ran on an
automatic choice or another substitute.

## When

- **Planning** — a decision touches a shared module or base type, a schema object other callers use,
  a public API or DTO, or shared config. Run it before the plan is persisted; the Engineering
  Decisions entry carries the safety fact and its proof level.
- **Implementing** — before any shared-owner change ([implement](../implement/playbooks/implement.md)
  step 4). The `ask-user` question carries the safety fact, its proof level, and the risks.
- **Reviewing** — a small diff you do not trust, or on request.

## Proof ladder

For each fact the change's safety depends on, get it as far down this list as is cheap, and say where
it stopped.

1. Said so — worthless alone.
2. Pointed at the line — a real `file:line`, or the library's own source.
3. Walked the failure path step by step, and it cannot reach.
4. Ran it — a scoped test or small script that calls the real code and fails loud if you are wrong.
5. Reproduced it in the running app.

Below 4 the fact is **unproven**. Say so instead of writing it up as settled.

## Steps

1. **Read the change** — symbols added, changed, and deleted, and what now behaves differently,
   including what the diff does not spell out.
2. **Find the one fact** it is safe because of, e.g. "only the detail page calls this overload".
   Spend the time here, not on a long list of maybes.
3. **Look where grep stops.**
   - Reflection, dynamic dispatch, late binding, and implicit conversions.
   - Names held in strings: dynamic queries, generated SQL, persisted sort/filter clauses, route
     and config keys, feature flags.
   - Markup, templates, and scripts that call server members by name; frontends embedded in other
     pages.
   - Repos downstream in `profile.json` `dependencyOrder`, and every app that shares the module.
   - Serialized shapes: API JSON, DB columns, and integration payloads.
4. **Rate each risk** — real likelihood and real cost. Keep the confirmed ones; list checked-and-
   cleared separately. Cite a real `file:line`. A search that finds nothing is still an answer. Never
   invent a caller.
5. **Prove the one fact** at level 4 when it is cheap: the nearest scoped test
   ([../../_shared/test-verification.md](../../_shared/test-verification.md)) or a small script
   against the real code. Paste the decisive output lines.
   - **While planning** (read-only Plan mode, and no ad-hoc scripts per `AGENTS.md`): go only as far as
     level 3, or level 4 by running a test that **already exists**. When the fact needs a new test,
     write `proof: level 3; level 4 = <the test to write>` in Engineering Decisions and make that test
     the plan's first step, so implementation proves it before it changes anything.

## Hand back

- **What it does** — including the part that is not obvious.
- **Safety fact** — the fact, its proof level (1–5), and the proof, or `unproven`.
- **Risks** — how it breaks, `file:line`, likelihood and cost, how to check.
- **Cleared** — what was checked and why it is fine.
- **Before merge** — the cheapest test or repro that would catch the real bug.
