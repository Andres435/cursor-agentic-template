---
name: model-routing
description: Engineering mode's router — the harness-neutral tier contract. Which tier each role and Work Plan step runs on, the difficulty rubric, and the dispatch rules. Names tiers only; each platform's adapter maps tiers to real models.
keywords: engineering mode, model routing, tier, fast, standard, deep, frontier, difficulty rubric, lane, dispatch, orchestrator, escalate, planner lane, lane probe
---

# Model Routing

This file names **tiers**, never models. Each platform maps tiers to real models in its adapter
([../adapters/README.md](../adapters/README.md)) and declares **`deepLane: inline | dispatch`** —
whether deep work stays in this chat or goes to a deep lane. A new platform is one new adapter with
a row per tier; `Assert-AgenticFlow` check `model-routing` fails on a missing row or on a model name
anywhere in the workflow docs. IDE actions use [harness-verbs.md](harness-verbs.md).

## Two layers

| Layer | On when | What it does |
|---|---|---|
| **Workflow** | Always | Every dispatch names its `model` from the tier of its role (table below). Subagent functions, the second-opinion review, and the architect and blast-radius lanes use these tiers in every chat. |
| **Engineering mode** | Appended to a chat — the engineering-mode skill, or the adapter's way to pin it — until the chat ends or the user says "exit engineering mode" | The chat becomes an **orchestrator**: the plan, each Work Plan step, and ad-hoc work run on their tier's model. Everything from "Orchestrator rule" down applies only here. |

Without engineering mode, the plan and every step run inline on the chat's model, as before.

## Tiers

| Tier | Work Plan tag | Meant for |
|---|---|---|
| `fast` | `[low]` | Mechanical, fully specified work |
| `standard` | `[med]` | A behavior change that follows an existing pattern |
| `deep` | `[high]` | Judgment — design, root cause, legacy risk |
| `frontier` | — | Only when the user asks for it in chat |

## Roles

| Role | Tier |
|---|---|
| Plan drafting and revision | deep |
| `explore-repo`, `why-repo`, `branch-setup`, `pr-feedback-fetch`, `verify-repo` | fast |
| `review-diff`, `peer-review-pr` | standard |
| Second-opinion reviewer (plan has a `[high]` step) | deep |
| Architect design lanes | one deep + one standard — two different models |
| Blast-radius | deep |

## Difficulty rubric

The overall tier is the highest signal present. A step's tag is never lower than the signals inside
that step.

- **deep** — a cross-repo contract; a shared owner other features depend on; a schema change; an unknown root
  cause; auth or security; money or payment math; transactions or concurrency; a design no
  accepted decision settles; a comment that contradicts the executable line; legacy behavior with no tests.
- **standard** — a behavior change inside one repo that follows an existing pattern; a focused bug
  with a known cause; new tests for known behavior.
- **fast** — renames, wiring, config, docs, routine test runs; fully specified, no behavior decision.

## Orchestrator rule

**Work runs on its tier's model.** The orchestrator does a piece inline only when its own model is
that tier's model in the adapter. Otherwise it dispatches. When the adapter maps a tier to the
chat's selected model, the orchestrator is on that tier for any named model. An IDE's automatic
choice, or a model that cannot be told, is not a selection: `ask-user` to pick a model, do not
name one, and do not dispatch that tier. No platform lets a chat switch its own model.

The orchestrator classifies, dispatches, reviews, writes the plan file and Deviations, and talks to
the user. On the fast tier it says once that classification and review are weaker there.

## Dispatch rules

1. **Explicit model.** Every dispatch passes `model` from the adapter. Omitting it inherits the
   orchestrator — the defect this contract exists to prevent.
2. **Lanes.** A lane is one dispatched subagent run. An implement lane covers one contiguous run of
   Work Plan steps with the same tag and the same repo path. Steps stay in plan order; one writer per repo path at a time.
3. **Lean packet.** Inline the step text. Pass the ticket id, the repo path from
   `Resolve-TicketRoot.ps1`, the manifest's `specialists[]` agent for that repo (else general-purpose),
   that repo's `explore-repo` key files, and a reminder to read the repo's `rules/`. Pointers,
   not dumps. The lane opens the plan only when its step cites another section.
4. **Lane return.** First line `model: <the model or family you are running on>`, then files
   changed · tests run and outcome · `assumed → actual` notes · `blocked: <stop condition>` for any
   stop-and-ask case from the implement playbook · `escalate: <why>`.
5. **Review.** Lane output at or below the orchestrator's tier: the orchestrator reads the lane's
   `git diff`. Above it: a `review-diff` lane on that tier reviews it. Only the orchestrator writes
   Deviations and reports `step N/M done`.
6. **Escalation.** At most one tier up, logged as a Deviation
   (`- <date> step N: [low] → standard; <why>`). Never route down after a failure. A failed deep lane
   stops the build and reports.
7. **Guardrail.** Lanes never spawn agents, commit, push, create PRs, or write the tracker
   ([subagent-functions.md](subagent-functions.md#global-guardrails)).
8. **No substitutes.** `[low]` and `[med]` dispatch. Deep and `[high]` follow the adapter's
   `deepLane`: `inline` runs them on the chat's selected model, never dispatched; `dispatch` sends
   them to the adapter's deep model, inline when the chat already runs on it. A lane whose `model:`
   line names another family, an automatic choice, `inherit`, or nothing has failed: discard its
   output and dispatch no more lanes on that tier in this chat. A discarded lane does not skip the
   step — run it inline and say so once. For a paired role (architect, second opinion) write your
   own candidate or review before reading the other lane's. If the model cannot be told, the wait
   is "pick a model"; do not name one. Never silently downgrade, never substitute frontier. Never
   leave the step unrun.
9. **Outside a Work Plan.** Ad-hoc edits and PR-comment fixes get the rubric and the same routing.
10. **Mode limits win.** Plan and Ask modes allow read-only lanes only (planner, explore, architect).
    If a mode exposes no subagents, the work runs inline and the orchestrator says so once.

## Planner lane

When the orchestrator is not on the deep tier, plan drafting goes to a deep planner lane. It returns
the draft, its Engineering Decisions, and open questions. The orchestrator asks the user and writes
the approved plan file. Revisions go back to the **same** planner, which re-emits only the changed
section ([ticket-plan-output.md](ticket-plan-output.md)). Where a platform cannot continue a lane,
send a fresh deep lane the current draft and the requested change. The adapter names the mechanism.

When the orchestrator is already deep, planning stays inline.

## Lane probe

`/doctor` dispatches one tiny read-only lane per tier and asks each which model it runs on. Record a
mismatch in the adapter as an unhonored tier (rule 8). Run it after changing a platform, a plan, or
an adapter.

## Related

- Principles the plan cites: [engineering-principles.md](engineering-principles.md)
- Plan tags and digest: [ticket-plan-output.md](ticket-plan-output.md)
- Fan-out contracts: [subagent-functions.md](subagent-functions.md)
