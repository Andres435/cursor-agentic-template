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

- **Work item number**: ADO work item ID such as `WI12345` or `AB#12345`
- **Title**: feature or work item title
- **Description**: what the feature should do
- **Acceptance criteria**: conditions that must be met

If the user provides a work item number, use [/start-ticket](../../../../commands/start-ticket.md) before planning. The startup flow owns the shared ADO intake, required-field gate, automatic **Ready for Dev** -> **In Progress** transition, latest `dev` update, `WI<ticketNumber>` branch creation, and then this feature implementation plan.

If ADO blocks the State transition because required fields are empty, report the blocking fields and continue feature planning.

If the user pasted a work item or ticket instead of an ID, extract these details from it and ask for the work item number if the ticket should be fetched or updated in ADO.

## Pre-Plan Gate (resolve before designing)

Confirm these up front; a wrong assumption here causes rework (WI17113, WI17114, WI17115, WI11422, WI18939):

- **External API contract:** when the feature calls an external/vendor API, confirm the exact request/response bodies and types before design.
- **AC vs description conflict:** when acceptance criteria and description disagree, **lock to the acceptance criteria** and call out the conflict.
- **Contract placement:** decide where new integration contracts live (integration-owned vs shared packages) before building.
- **Vendor enum naming:** map to the vendor API's enum names, not your internal `enum.ToString()` equivalents.

## Workflow

**Switch to Plan mode automatically** and build the full plan there. Follow [../../../../_shared/ticket-plan-output.md](../../../../_shared/ticket-plan-output.md) — the plan lives in Plan mode, not in the chat tab.

When invoked from [/start-ticket](../../../../commands/start-ticket.md), call `SwitchMode` without asking the user to confirm. `/start-ticket` owns approval and the final message: Approved plan, then the copy-paste fence last ([ticket-plan-output.md](../../../../_shared/ticket-plan-output.md)).

Include a numbered **Work Plan** section at the end of the plan. Tag every step `[low]|[med]|[high]` per [../../../../_shared/ticket-plan-output.md](../../../../_shared/ticket-plan-output.md) so implementation picks Auto/Composer vs Grok.

UI/CSS verification: [../../../../_shared/runtime-verify.md](../../../../_shared/runtime-verify.md) — no CDP, no server rebuild for markup/CSS.

### 1. Environment Context

Use [../../../domain/environment-context/SKILL.md](../../../domain/environment-context/SKILL.md) before broad code search. Include matched cards, likely repos/projects, first search targets, test scope, and gotchas.

### 2. Feature Overview

Summarize the user-facing or API-facing outcome and the main behavior changes.

### 3. Behavior Slices

Plan features as behavior slices:

1. List observable behaviors from the acceptance criteria.
2. Choose the smallest behavior that proves the path.
3. **Default to RED -> GREEN -> REFACTOR** for any behavior-heavy, risky, or cross-layer logic. Skip TDD only for trivial wiring (e.g. a pass-through DTO property) and note the reason explicitly.
4. Use existing fixtures and test helpers before creating new test structure.
5. Avoid writing every test up front; each passing slice should inform the next one.
6. Broaden test scope only after the focused slice is green.

Use [../../../domain/tdd-red-green-refactor/SKILL.md](../../../domain/tdd-red-green-refactor/SKILL.md) to drive behavior-heavy or risky slices through the RED -> GREEN -> REFACTOR loop.

### 4. Affected Repositories

Identify all repos and layers affected. Use [../../../../_shared/cross-repo-workflow.md](../../../../_shared/cross-repo-workflow.md) for dependency order and likely repo combinations.

### 5. Data Model Changes

Plan schema/database changes first when needed. Apply datetime conventions for system-generated vs user-entered date/time fields.

### 6. Backend Implementation

Plan DTOs, services, API endpoints, DI registration, decorators, handlers, and validation.

- For new or modified API endpoints, follow [../../../domain/new-api-endpoint/SKILL.md](../../../domain/new-api-endpoint/SKILL.md).
- For backend conventions, use [../../../../agents/dotnet-specialist.md](../../../../agents/dotnet-specialist.md) and [../../../../rules/dotnet-overlay.mdc](../../../../rules/dotnet-overlay.mdc).
- When `adrIndex` is set, consult the ADR index before choosing a pattern — see
  [../../../../_shared/adr-policy.md](../../../../_shared/adr-policy.md). Cite the ADRs this section follows.

### 7. Frontend Implementation

Plan components, data hooks, forms, state, and MUI usage.

- For new or modified React features, follow [../../../domain/new-react-feature/SKILL.md](../../../domain/new-react-feature/SKILL.md).
- For project-specific frontend stack differences (MUI version, zod, zustand, etc.), use [../../../../agents/react-specialist.md](../../../../agents/react-specialist.md).

### 8. Integration Points

Describe how the feature connects with existing workflows, handlers, legacy code, external APIs, or environment cards. Flag C-Class changes as high risk and require approval.
When `git blame` or `git log` reveals historical work item IDs while researching existing behavior, use the read-only lookup path in [./ado-ticket-workflow.md](./ado-ticket-workflow.md) for context. Do not write to historical tickets.

### 9. Testing Plan

Use [../../../../_shared/test-verification.md](../../../../_shared/test-verification.md). Include focused automated tests, nearest broader test scope, and manual verification when UI or external integration behavior is involved.

### 10. Verification

- Run SonarQube checks per [../../../../_shared/sonar-verification.md](../../../../_shared/sonar-verification.md).
- Review the plan and eventual changes against [../../../../_shared/review-protocol.md](../../../../_shared/review-protocol.md).
- Note any documentation updates in TmoDocs.

### 11. ADR Compliance

Follow [../../../../_shared/adr-policy.md](../../../../_shared/adr-policy.md). When `adrIndex` is set:

- Cite the Accepted ADRs this plan follows — list gathered while writing section 6.
- If a step conflicts with an Accepted ADR, name it and flag the conflict explicitly.
- If a step introduces a genuinely new pattern with no covering ADR, note it as an ADR-stub candidate.
- No ADR index, or nothing rises to architectural-decision weight: write "None."

### 12. Confidence Score

Fill out [../../../../_shared/confidence-score.md](../../../../_shared/confidence-score.md), using `Design certainty` as the second-row axis. If `Design certainty` is Med or Low, recommend a tech spike using [tech-spike.md](tech-spike.md).

### 13. Closeout (User-Invoked)

Do not run closeout automatically after planning or implementation. When the user is ready to stop and review the work, they invoke [/complete-task](../../../../commands/complete-task.md).
