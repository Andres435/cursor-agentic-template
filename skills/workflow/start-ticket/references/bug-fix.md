---
name: bug-fix
description: Plan and investigate bug fixes. Use when the user provides a defect, repro steps, actual behavior, expected behavior, crash, regression, or asks for a bug-fix plan.
keywords: bug, defect, repro steps, root cause, regression, hypothesis, bug plan
---

# Bug Fix Investigation

## Purpose

Guide bug investigation from symptoms to root cause, regression protection, implementation plan, and verification.

## Gather Input

Ask for any missing essentials:

- **Work item number**: ADO work item ID such as `WI12345` or `AB#12345`
- **Title**: bug or work item title
- **Description**: what is happening
- **Steps to reproduce**: how to trigger the bug
- **Actual behavior**: what currently happens
- **Expected behavior**: what should happen instead

### Symptom + environment gate (before investigating)

Nail these down first; missing them causes wrong-repo exploration and rework (WI18345, WI21270, WI20657, WI20658):

- **Concrete QA symptom:** the exact observed behavior (e.g. Loom: "generic admin error on first retry, second succeeds"; report shows design-time placeholder `SECURITIES/99/99`), not just "it's broken".
- **Environment/data constraints:** empty tables (e.g. IntegrationHub payment table), one client mapped to multiple databases, whether the feature flag is on/off for the failing client, and whether **flag-off is also broken** (tells you if it is a legacy vs modern-path bug — skips wrong-repo hunting).
- **Test matrix (data-shaped bugs):** for payments/report bugs, agree the matrix — client, database, billing period, mixed locked/premium rows, 24h boundary — before changing a fingerprint or query shape.

If the user provides a work item number, use [/start-ticket](../../../../commands/start-ticket.md) before planning. The startup flow owns the shared ADO intake, required-field gate, automatic **Ready for Dev** -> **In Progress** transition, latest `dev` update, `WI<ticketNumber>` branch creation, and then this bug investigation/fix plan.

If ADO blocks the State transition because required fields are empty, report the blocking fields and continue the bug investigation.

If the user pasted a work item or ticket instead of an ID, extract these details from it and ask for the work item number if the ticket should be fetched or updated in ADO.

## Workflow

**Switch to Plan mode automatically** and build the full plan there. Follow [../../../../_shared/ticket-plan-output.md](../../../../_shared/ticket-plan-output.md) — the plan lives in Plan mode, not in the chat tab.

When invoked from [/start-ticket](../../../../commands/start-ticket.md), call `SwitchMode` without asking the user to confirm. `/start-ticket` owns approval and the final message: Approved plan, then the copy-paste fence last ([ticket-plan-output.md](../../../../_shared/ticket-plan-output.md)).

Include a numbered **Work Plan** section at the end of the plan. Tag every step `[low]|[med]|[high]` per [../../../../_shared/ticket-plan-output.md](../../../../_shared/ticket-plan-output.md) so implementation picks Auto/Composer vs Grok.

UI/CSS verification (if the bug is visual): [../../../../_shared/runtime-verify.md](../../../../_shared/runtime-verify.md) — no CDP, no server rebuild for markup/CSS.

### 1. Environment Context

Use [../../../domain/environment-context/SKILL.md](../../../domain/environment-context/SKILL.md) before broad code search. Include matched cards, likely repos/projects, first search targets, test scope, and gotchas.

### 2. Investigation Strategy

- Identify files, logs, data conditions, and code paths to inspect first.
- Search across repos when the bug may span layers.
- Check both modern and legacy code paths when the bug may span multiple layers.

### 2b. Already-fixed / sibling-PR gate (before crediting a cause)

When QA (or the user) says the bug is already gone, or the plan would touch `LegacyModalSupport` / overlay z-index / modal dispose:

1. On the affected repo, do not stop at the newest similarly named merge (`z-index`, `tmomodal`, `renderX`). Also run `git log --oneline --grep=revert -20` and `git log --diff-filter=D --summary -- <suspected paths>` so a **deleted** helper is not missed.
2. If the active work item has Related links, `wit_work_item` get those IDs (still `project: "Net"`) and read `Custom.RootCauseAnalysis` — WI21709 named WI21275/WI21657 as the regressors; a recent overlay PR did not.
3. Look for recently deleted helpers (run `git log --diff-filter=D --summary -- <suspected paths>`) — a fix that reinvents deleted code is usually wrong.

### 3. Affected Components

- List affected repos, services, controllers, handlers, UI surfaces, database objects, and docs.
- Follow [../../../../_shared/cross-repo-workflow.md](../../../../_shared/cross-repo-workflow.md) for dependency order.
- Flag shared libraries such as `TmoPortalCore`.

### 4. Root Cause Analysis

- Explain the likely cause and why the behavior escaped existing coverage.
- Search for the same pattern elsewhere when the bug suggests a reusable defect.
- When `git blame` or `git log` reveals historical work item IDs, use the read-only lookup path in [./ado-ticket-workflow.md](./ado-ticket-workflow.md) for context. Do not write to historical tickets.
- If root-cause certainty is low, recommend the smallest additional investigation before coding.

### 5. Bug Fix Test Policy

Before changing production code:

1. Search for existing tests around the affected behavior.
2. If a relevant test already fails for the reported bug, use that as the RED signal.
3. If no existing test proves the bug, add the smallest focused regression test in the nearest appropriate fixture.
4. Run the test and confirm it fails for the expected reason.
5. Make the smallest production change required to pass.
6. Re-run the focused test, then the nearest broader test scope.
7. Refactor only while tests are green.

Use [../../../domain/tdd-red-green-refactor/SKILL.md](../../../domain/tdd-red-green-refactor/SKILL.md) when the user asks for TDD/test-first work or the fix is risky enough to benefit from strict RED -> GREEN -> REFACTOR.

### 6. Proposed Fix

- Plan the smallest code change that corrects behavior.
- Respect repo-specific conventions and DateTime rules.
- When `adrIndex` is set, check the fix against the ADR index — a fix that contradicts an Accepted ADR
  should follow it or flag the conflict explicitly. See [../../../../_shared/adr-policy.md](../../../../_shared/adr-policy.md).
  Most bug fixes cite no ADR; that's normal.
- Do not change core/protected logic without user approval.
- Use characterization tests first for risky legacy behavior when practical.

### 7. Verification

- Run tests per [../../../../_shared/test-verification.md](../../../../_shared/test-verification.md).
- Run SonarQube checks per [../../../../_shared/sonar-verification.md](../../../../_shared/sonar-verification.md).
- Review using [../../../../_shared/review-protocol.md](../../../../_shared/review-protocol.md).
- Include manual verification steps when UI, data setup, or external integration behavior is involved.

### 8. Prevention

- Identify regression tests, documentation, or environment card updates that should prevent recurrence.
- Note similar code patterns to audit across repos.

### 9. Confidence Score

Fill out [../../../../_shared/confidence-score.md](../../../../_shared/confidence-score.md), using `Root-cause certainty` as the second-row axis. If `Root-cause certainty` is Med or Low, recommend additional investigation before implementation.

### 10. Closeout (User-Invoked)

Do not run closeout automatically after verification. When the user is ready to stop and review the work, they invoke [/complete-task](../../../../commands/complete-task.md).
