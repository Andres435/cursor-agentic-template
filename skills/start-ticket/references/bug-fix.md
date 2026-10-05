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

- **Ticket id**: the tracker id, using `profile.ticketPrefix`
- **Title**: bug or work item title
- **Description**: what is happening
- **Steps to reproduce**: how to trigger the bug
- **Actual behavior**: what currently happens
- **Expected behavior**: what should happen instead

### Symptom + environment gate (before investigating)

Each item below is a **decision candidate**: confirm it, or ask the user. Whatever you confirm is
recorded in the plan's Engineering Decisions section (step 5b) —
[../../../_shared/engineering-decisions.md](../../../_shared/engineering-decisions.md).
An item still open when the Work Plan would be drafted stops the plan; it does not become a default.

Nail these down first; missing them causes wrong-repo exploration and rework:

- **Concrete symptom:** the exact observed behavior (the message, the wrong value, the sequence that fails on first try and works on the second), not just "it's broken".
- **Environment/data constraints:** empty tables, one customer mapped to several databases, whether the feature flag is on/off for the failing case, and whether **flag-off is also broken** (tells you if it is a legacy vs modern-path bug — skips wrong-repo hunting).
- **Test matrix (data-shaped bugs):** for payment or report bugs, agree the matrix — customer, database, period, mixed row kinds, time-boundary cases — before changing a query shape or fingerprint.

If a ticket id is present, `/start-ticket` already owns intake and branches. Do not re-ask
profile fields (repos, stack, prefix).

## Workflow

**Switch to Plan mode automatically** and build the full plan there. Follow [../../../_shared/ticket-plan-output.md](../../../_shared/ticket-plan-output.md) — the plan lives in Plan mode, not in the chat tab.

When invoked from [/start-ticket](../SKILL.md), run `enter-plan` ([harness-verbs](../../../_shared/harness-verbs.md)) without asking the user to confirm. `/start-ticket` owns approval and the final message: Approved plan, then the copy-paste fence last ([ticket-plan-output.md](../../../_shared/ticket-plan-output.md)).

Include a numbered **Work Plan** section at the end of the plan. Tag every step `[low]|[med]|[high]` per [../../../_shared/ticket-plan-output.md](../../../_shared/ticket-plan-output.md) — the tag is the tier the step runs on ([../../../_shared/model-routing.md](../../../_shared/model-routing.md#difficulty-rubric)).

UI/CSS verification (if the bug is visual): [../../../_shared/runtime-verify.md](../../../_shared/runtime-verify.md) — no CDP, no server rebuild for markup/CSS.

### 1. Environment Context

Use [../../environment-context/SKILL.md](../../environment-context/SKILL.md) before broad code search. Include matched cards, likely repos/projects, first search targets, test scope, and gotchas.

### 2. Investigation Strategy

- Identify files, logs, data conditions, and code paths to inspect first.
- Search across repos when the bug may span layers.
- Check both modern and legacy code paths when the bug may span multiple layers.

### 2b. Already-fixed / sibling-PR gate (before crediting a cause)

When QA (or the user) says the bug is already gone, or the plan would touch shared teardown/overlay code:

1. On the affected repo, do not stop at the newest similarly named merge. Also run `git log --oneline --grep=revert -20` and `git log --diff-filter=D --summary -- <suspected paths>` so a **deleted** helper is not missed.
2. If `profile.ticketSystem` is not `none` and the active ticket has related links, read those tickets (read-only) and any root-cause field — the named regressor is often not the most recent similar PR.
3. A fix that reinvents a recently deleted helper is usually wrong; find out why it was removed.

### 3. Affected Components

- List affected repos, services, controllers, handlers, UI surfaces, database objects, and docs.
- Follow [../../../_shared/cross-repo-workflow.md](../../../_shared/cross-repo-workflow.md) for dependency order.
- Flag shared libraries named in `profile.json` / the env card.

### 4. Root Cause Analysis

- Explain the likely cause and why the behavior escaped existing coverage.
- Cite the **executable statement**, not a comment or doc-comment that describes it (a mismatch is a finding, not the behavior).
- Search for the same pattern elsewhere when the bug suggests a reusable defect.
- When `git blame` or `git log` reveals historical ticket IDs, look them up read-only. Do not write to historical tickets.
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

Use [../../tdd-red-green-refactor/SKILL.md](../../tdd-red-green-refactor/SKILL.md) when the user asks for TDD/test-first work or the fix is risky enough to benefit from strict RED -> GREEN -> REFACTOR.

### 5b. Engineering Decisions

Record the calls resolved by the symptom/environment gate plus anything root-cause analysis forced,
in the shape defined by
[../../../_shared/engineering-decisions.md](../../../_shared/engineering-decisions.md).
This sits after root cause and before the fix, because on a bug the fix-shape call depends on the
cause — the intake-time calls (environment, test matrix, already-fixed) are simply carried here.

Bug candidates:

- **Fix layer** — legacy path, modern path, or both; which repo owns the correct behavior. Write
  it as `Fix layer: <layer>`.
- **Blast radius** — a shared or protected type or shared library change (needs approval) vs a
  contained fix. A shared owner runs [../../blast-radius/SKILL.md](../../blast-radius/SKILL.md); the
  entry carries its safety fact and proof level.
- **Fix shape** — a deep fix that crosses a module or repo boundary runs
  [../../architect/SKILL.md](../../architect/SKILL.md). Otherwise, when any Work
  Plan step is `[high]`, write `architect skipped: <reason>` (the start gate checks it).
- **Symptom scope** — the failing case this ticket fixes, and any sibling case it explicitly does not.
- **Coverage gap** — the regression test that proves the bug, and what stays uncovered on purpose.
- **ADR conflict** — when `adrIndex` is set, a fix reaching for a pattern an Accepted ADR settled
  differently.

Most bug fixes are small: `None — <why>` is a normal and expected answer. Cite a principle from
[../../../_shared/engineering-principles.md](../../../_shared/engineering-principles.md) only
in the **Why** of a decision it changed.

### 6. Proposed Fix

- Plan the smallest code change that corrects behavior.
- Respect repo-specific conventions and DateTime rules.
- When `adrIndex` is set, check the fix against the ADR index — a fix that contradicts an Accepted ADR
  should follow it or flag the conflict explicitly. See [../../../_shared/adr-policy.md](../../../_shared/adr-policy.md).
  Most bug fixes cite no ADR; that's normal.
- Do not change core/protected logic without user approval.
- Use characterization tests first for risky legacy behavior when practical.

### 7. Verification

- Run tests per [../../../_shared/test-verification.md](../../../_shared/test-verification.md).
- Run the quality gate only when the manifest lists a key for that repo.
- Review using [../../../_shared/review-protocol.md](../../../_shared/review-protocol.md).
- Include manual verification steps when UI, data setup, or external integration behavior is involved.

### 8. Prevention

- Identify regression tests, documentation, or environment card updates that should prevent recurrence.
- Note similar code patterns to audit across repos.

### 9. Confidence Score

Fill out [../../complete-task/references/confidence-score.md](../../complete-task/references/confidence-score.md), using `Root-cause certainty` as the second-row axis. If `Root-cause certainty` is Med or Low, recommend additional investigation before implementation.

### 10. Closeout (User-Invoked)

Do not run closeout automatically after verification. When the user is ready to stop and review the work, they invoke [/complete-task](../../complete-task/SKILL.md).
