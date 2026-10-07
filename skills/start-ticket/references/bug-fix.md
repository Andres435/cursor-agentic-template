---
name: bug-fix
description: Plan and investigate bug fixes. Use when the user provides a defect, repro steps, actual behavior, expected behavior, crash, regression, or asks for a bug-fix plan.
keywords: bug, defect, repro steps, root cause, regression, never-worked, why-repo, hypothesis, bug plan
---

# Bug Fix Investigation

The bug plan's content, from symptom to root cause, regression test, and fix. `/start-ticket` loads
it at step 6 and owns intake, plan mode, approval, and the final message; structure, digest, and
step tags follow [../../../_shared/ticket-plan-output.md](../../../_shared/ticket-plan-output.md).
Visual bugs verify per [../../../_shared/runtime-verify.md](../../../_shared/runtime-verify.md)
(ask-first browser pass). No server rebuild for markup/CSS.

## Symptom + environment gate (before investigating)

Each item is a **decision candidate**: confirm it or ask. What you confirm goes in Engineering
Decisions (§5b, [../../../_shared/engineering-decisions.md](../../../_shared/engineering-decisions.md));
an item still open when the Work Plan would be drafted stops the plan. Missing these causes
wrong-repo exploration and rework:

- **Concrete symptom:** the exact observed behavior (the message, the wrong value, the sequence that fails on first try and works on the second), not just "it's broken".
- **Regression vs never-worked:** did this used to work and break recently, or did it never work? Confirm or ask; do not guess. **Used to work** → after explore, dispatch `why-repo` ([../../../_shared/subagent-functions.md](../../../_shared/subagent-functions.md#why-reporepo-files---history)), then look up `tickets[]` read-only when `profile.ticketSystem` is not `none`. **Never worked** → `why skipped: never worked`; no git blame or log. Record the call in Engineering Decisions.
- **Environment/data constraints:** empty tables, one customer mapped to several databases, whether the feature flag is on/off for the failing case, and whether **flag-off is also broken** (legacy vs modern-path bug — skips wrong-repo hunting).
- **Test matrix (data-shaped bugs):** for payment or report bugs, agree the matrix — customer, database, period, mixed row kinds, time-boundary cases — before changing a query shape or fingerprint.

## 1. Environment Context

Use [../../environment-context/SKILL.md](../../environment-context/SKILL.md) before broad code search: matched cards, likely repos/projects, first search targets, test scope, gotchas.

## 2. Investigation Strategy

- Identify files, logs, data conditions, and code paths to inspect first; search across repos when the bug may span layers.
- Check both modern and legacy code paths when the bug may span multiple layers.

### 2b. Already-fixed / sibling-PR gate (before crediting a cause)

When QA (or the user) says the bug is already gone, or the plan would touch shared teardown/overlay code:

1. On the affected repo, do not stop at the newest similarly named merge. Also run `git log --oneline --grep=revert -20` and `git log --diff-filter=D --summary -- <suspected paths>` so a **deleted** helper is not missed.
2. If `profile.ticketSystem` is not `none` and the active ticket has related links, read those tickets (read-only) and any root-cause field — the named regressor is often not the most recent similar PR.
3. A fix that reinvents a recently deleted helper is usually wrong; find out why it was removed.

## 3. Affected Components

List affected repos, services, controllers, handlers, UI surfaces, database objects, and docs, in [../../../_shared/cross-repo-workflow.md](../../../_shared/cross-repo-workflow.md) dependency order. Flag shared libraries named in `profile.json` / the env card.

## 4. Root Cause Analysis

- Explain the likely cause and why it escaped existing coverage.
- Cite the **executable statement**, not a comment or doc-comment that describes it (a mismatch is a finding, not the behavior).
- Search for the same pattern elsewhere when the bug suggests a reusable defect.
- **Used to work:** consume the `why-repo` packet (files, tickets, why, deleted). Look up `tickets[]` read-only when `profile.ticketSystem` is not `none`. Never write to historical tickets. Do not credit a cause from the newest similarly named merge alone.
- **Never worked:** skip blame and history (`why skipped: never worked`) and go straight to the mechanism. `why skipped: no keyFiles` when explore returned none.
- Root-cause certainty H/M/L goes on the Plan Digest Risk line; M or L → recommend more investigation before build.

## 5. Regression test first

The Work Plan's first code step is RED: an existing failing test, or the smallest focused regression
test in the nearest fixture, failing for the expected reason. When no test can exist (a page with
no test project in reach), step 1 says `no-test: <reason>` instead; `-Phase start` fails a bug plan
whose first step does neither. Then the smallest production change,
the focused test, the nearest broader scope; refactor only while green. Strict RED → GREEN → REFACTOR:
[../../tdd-red-green-refactor/SKILL.md](../../tdd-red-green-refactor/SKILL.md).

## 5b. Engineering Decisions

Record the gate's calls plus anything root cause forced. It sits after root cause because on a bug the
fix-shape call depends on the cause. Candidates:

- **Regression vs never-worked** — used to work (`why-repo`, then a read-only lookup) vs never worked (no blame).
- **Fix layer** — legacy path, modern path, or both; which repo owns the correct behavior. Write
  it as `Fix layer: <layer>`.
- **Blast radius** — a shared or protected type or shared library change (needs approval) vs a
  contained fix. A shared owner runs [../../blast-radius/SKILL.md](../../blast-radius/SKILL.md); the
  entry carries its safety fact and proof level.
- **Fix shape** — a deep fix that crosses a module or repo boundary runs
  [../../architect/SKILL.md](../../architect/SKILL.md). Otherwise, with any `[high]` step, write
  `architect skipped: <reason>` (the start gate checks it).
- **Symptom scope** — the failing case this ticket fixes, and any sibling case it explicitly does not.
- **Coverage gap** — the regression test that proves the bug, and what stays uncovered on purpose.
- **ADR conflict** — when `adrIndex` is set, a fix reaching for a pattern an Accepted ADR settled
  differently.

Most bug fixes are small: `None — <why>` is normal. Cite a principle from
[../../../_shared/engineering-principles.md](../../../_shared/engineering-principles.md) only in the
**Why** of a decision it changed.

## 6. Proposed Fix

- The smallest change that corrects behavior, within repo conventions and DateTime rules.
- When `adrIndex` is set, follow the ADR index or flag the conflict ([../../../_shared/adr-policy.md](../../../_shared/adr-policy.md)). Most bug fixes cite no ADR.
- No core/protected logic change without user approval; characterization tests first for risky legacy behavior.

## 7. Verification

The plan lists manual steps only when UI, data setup, or an external integration is involved. Tests,
the quality gate, and review run in `implement` and `/complete-task` from the manifest `docSet`
([../../../_shared/test-verification.md](../../../_shared/test-verification.md),
[../../../_shared/review-protocol.md](../../../_shared/review-protocol.md)).

## 8. Prevention

Name the regression tests, docs, or environment card updates that prevent recurrence, and similar
patterns to audit across repos. Closeout is user-invoked `/complete-task`.
