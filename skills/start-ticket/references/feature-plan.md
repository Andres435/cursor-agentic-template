---
name: feature-plan
description: Plan feature implementation across TMO repos. Use when the user provides a feature, acceptance criteria, new workflow, API/UI behavior, integration change, or asks for an implementation plan.
keywords: feature, acceptance criteria, user story, feature plan, work plan
---

# Feature Implementation Plan

## Purpose

Create a feature plan from requirements through behavior slices, affected repos, implementation layers, tests, verification, and confidence scoring.

## Gather Input

Ask for any missing essentials:

- **Ticket id**: the tracker id, using `profile.ticketPrefix`
- **Title**: feature or work item title
- **Description**: what the feature should do
- **Acceptance criteria**: conditions that must be met

If a ticket id is present, `/start-ticket` owns intake. Do not re-ask profile fields.

## Pre-Plan Gate (resolve before designing)

Each item below is a **decision candidate**: confirm it, or ask the user. Whatever you confirm is
recorded in the plan's Engineering Decisions section (step 2b) —
[../../../_shared/engineering-decisions.md](../../../_shared/engineering-decisions.md).
An item still open when the Work Plan would be drafted stops the plan; it does not become a default.

A wrong assumption here causes rework:

- **External API contract:** when the feature calls an external/vendor API, confirm the exact request/response bodies and types before design. A mock must echo generated IDs and honor the vendor's request filters.
- **AC vs description conflict:** when acceptance criteria and description disagree, **lock to the acceptance criteria** and call out the conflict.
- **Contract placement:** decide where new integration contracts live (integration-owned vs shared packages) before building.
- **Vendor enum naming:** map to the vendor API's enum names, not your internal `enum.ToString()` equivalents.

## Clarify batch

If the acceptance criteria, the description, or a Pre-Plan Gate item is ambiguous, ask **at most five
questions in one turn** (`ask-user`). Do not drip them across turns. Write each answer into
Engineering Decisions before drafting the Work Plan. An answer that stays only in chat is not resolved.

## Workflow

**Switch to Plan mode automatically** and build the full plan there. Follow [../../../_shared/ticket-plan-output.md](../../../_shared/ticket-plan-output.md) — the plan lives in Plan mode, not in the chat tab.

When invoked from [/start-ticket](../SKILL.md), run `enter-plan` ([harness-verbs](../../../_shared/harness-verbs.md)) without asking the user to confirm. `/start-ticket` owns approval and the final message: Approved plan, then the copy-paste fence last ([ticket-plan-output.md](../../../_shared/ticket-plan-output.md)).

Include a numbered **Work Plan** section at the end of the plan. Tag every step `[low]|[med]|[high]` per [../../../_shared/ticket-plan-output.md](../../../_shared/ticket-plan-output.md) — the tag is the tier the step runs on ([../../../_shared/model-routing.md](../../../_shared/model-routing.md#difficulty-rubric)).

Each step cites the behavior it satisfies (`B1`, `B2`) or `Foundational` when it blocks every behavior. A step with no behavior id, or a behavior with no step, is a plan defect. When there are three or more behaviors, group the steps **Foundational**, then one group per behavior in priority order. Cross-repo order inside a group still follows [../../../_shared/cross-repo-workflow.md](../../../_shared/cross-repo-workflow.md).

TDD belongs on the Work Plan, not on the behavior list. **Default to RED -> GREEN -> REFACTOR** for any behavior-heavy, risky, or cross-layer step. Skip TDD only for trivial wiring (e.g. a pass-through DTO property) and note the reason on that step. Use existing fixtures before new test structure. Do not write every test up front. Use [../../tdd-red-green-refactor/SKILL.md](../../tdd-red-green-refactor/SKILL.md) for behavior-heavy steps.

UI/CSS verification: [../../../_shared/runtime-verify.md](../../../_shared/runtime-verify.md) — no CDP, no server rebuild for markup/CSS.

### 1. Environment Context

Use [../../environment-context/SKILL.md](../../environment-context/SKILL.md) before broad code search. Include matched cards, likely repos/projects, first search targets, test scope, and gotchas.

### 2. Feature Overview

Summarize the user-facing or API-facing outcome and the main behavior changes.

### 2b. Engineering Decisions

Record the calls resolved by the Pre-Plan Gate and the clarify batch, in the shape defined by
[../../../_shared/engineering-decisions.md](../../../_shared/engineering-decisions.md).
This section is written **before** the Behaviors list below, because a boundary decided late is a
behavior rewritten.

Features almost always have at least one. The usual candidates:

- **Contract placement** — integration-owned vs shared packages.
- **Scope boundary** — which repos and layers this ticket delivers, and which follow-up owns the rest.
- **Feature flag** — the flag name, and whether flag-off behavior is also in scope.
- **Vendor contract** — enum names, request/response shape, auth, and mock behavior.
- **AC vs description conflict** — AC wins; name the conflict rather than silently resolving it.
- **Design shape** — a deep change that crosses a module or repo boundary, or adds a type, contract,
  table, or endpoint no Accepted ADR settles, runs
  [../../architect/SKILL.md](../../architect/SKILL.md): the winner is the
  Decision, the loser its Rejected. Otherwise, with any `[high]` step, write
  `architect skipped: <reason>` (the start gate checks it).
- **Shared owner** — a shared or protected type, shared schema object, shared library contract, or
  public DTO runs [../../blast-radius/SKILL.md](../../blast-radius/SKILL.md); the entry
  carries its safety fact and proof level.

If none apply, write `None —` with the one clause saying why. Cite a principle from
[../../../_shared/engineering-principles.md](../../../_shared/engineering-principles.md) only
in the **Why** of a decision it changed.

### 3. Behaviors

Observable behavior only — what a user or API caller can see. No file paths, no repos, no layers.

If the user points at an existing spec with a behavior list, load it and use its behaviors as this
list. Do not re-interview them.

```markdown
## Behaviors
- **B1** (P1): <observable behavior>
  - **Check:** <how this behavior is proven on its own>
- **B2** (P2): ...
  - **Check:** ...
```

One behavior per acceptance criterion that names a distinct outcome. Priority is P1, then P2, then P3.

### Consistency report

Immediately before asking for approval, report these three lists in chat:

- Behaviors with no Work Plan step
- Work Plan steps with no behavior id
- Engineering Decisions that contradict an acceptance criterion

Do not offer the draft for approval, and do not persist, until each list is empty or the user
explicitly accepts that item as out of scope. Record an accepted omission in Engineering Decisions.

### 4. Affected Repositories

Identify all repos and layers affected. Use [../../../_shared/cross-repo-workflow.md](../../../_shared/cross-repo-workflow.md) for dependency order and likely repo combinations.

### 5. Data Model Changes

Plan schema/database changes first when needed. Apply datetime conventions for system-generated vs user-entered date/time fields.

### 6. Backend Implementation

Plan DTOs, services, API endpoints, DI registration, decorators, handlers, and validation.

- Follow the specialist in `profile.specialists` / `agents/` for backend conventions.
- When `adrIndex` is set, consult the ADR index before choosing a pattern — see
  [../../../_shared/adr-policy.md](../../../_shared/adr-policy.md). Cite the ADRs this section follows.

### 7. Frontend Implementation

Plan components, data hooks, forms, state, and MUI usage.

- Follow the specialist in `agents/` for frontend conventions.

### 8. Integration Points

Describe how the feature connects with existing workflows, handlers, legacy code, external APIs, or environment cards. Flag shared-owner changes as high risk and require approval.
When `git blame` or `git log` reveals historical ticket IDs, look them up read-only. Do not write to historical tickets.

### 9. Testing Plan

Use [../../../_shared/test-verification.md](../../../_shared/test-verification.md). Include focused automated tests, nearest broader test scope, and manual verification when UI or external integration behavior is involved.

### 10. Verification

- Run the quality gate only when the manifest lists a key for that repo.
- Review the plan and eventual changes against [../../../_shared/review-protocol.md](../../../_shared/review-protocol.md).
- Note any documentation updates the change needs.

### 11. ADR Compliance

Follow [../../../_shared/adr-policy.md](../../../_shared/adr-policy.md). When `adrIndex` is set:

- Cite the Accepted ADRs this plan follows — list gathered while writing section 6.
- If a step conflicts with an Accepted ADR, name it and flag the conflict explicitly.
- If a step introduces a genuinely new pattern with no covering ADR, note it as an ADR-stub candidate.
- No ADR index, or nothing rises to architectural-decision weight: write "None."

### 12. Confidence Score

Fill out [../../complete-task/references/confidence-score.md](../../complete-task/references/confidence-score.md), using `Design certainty` as the second-row axis. If `Design certainty` is Med or Low, recommend a tech spike using [tech-spike.md](tech-spike.md).

### 13. Closeout (User-Invoked)

Do not run closeout automatically after planning or implementation. When the user is ready to stop and review the work, they invoke [/complete-task](../../complete-task/SKILL.md).
