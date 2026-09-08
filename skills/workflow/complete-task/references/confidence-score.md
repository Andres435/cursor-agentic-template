---
name: confidence-score
description: Workspace standard for confidence scoring across bugs, features, spikes, refactors, and reviews.
keywords: confidence score, root-cause certainty, design certainty, findings certainty, axes
---

# Confidence Score (workspace standard)

Every bug, feature, change, spike, and review ends with this block. Each consumer fills the second-row axis with the value listed below.

## Template

```markdown
## Confidence Score

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Scope clarity | High / Med / Low | one-line note |
| <axis> | High / Med / Low | one-line note |
| Fix / Implementation correctness | High / Med / Low | one-line note |
| Regression risk (Low = best) | Low / Med / High | one-line note |
| **Overall confidence** | **High / Med / Low** | one-line rationale |

### Risks / Unknowns
- bullet 1
- bullet 2
```

## Axis values per consumer

| Consumer | `<axis>` value |
|----------|----------------|
| `commands/bug-fix.md` | Root-cause certainty |
| `commands/feature-plan.md` | Design certainty |
| `commands/tech-spike.md` | Findings certainty |
| `commands/review-changes.md` and `agents/code-reviewer.md` | Change-set understanding |
| `skills/conventions/sync-tracked-conventions` | Detection coverage |
| `skills/workflow/ticket-workflow` and `skills/domain/multi-repo-change` | Whichever axis matches the underlying ticket type (bug -> Root-cause certainty, feature -> Design certainty, spike -> Findings certainty, change-set review -> Change-set understanding) |

## How to rate each dimension

- **Scope clarity** -- Are the requirements / repro / acceptance criteria fully understood?
  - High: nothing material is ambiguous
  - Med: 1-2 minor open questions that won't change the approach
  - Low: significant ambiguity that could change the approach
- **Domain certainty axis** (Root-cause / Design / Findings / Change-set understanding) -- Confidence the analysis is correct.
- **Fix / Implementation correctness** -- Confidence the proposed change correctly addresses scope without unintended side effects.
- **Regression risk** (inverted -- Low is best) -- Likelihood the change breaks something else.
  - Low: isolated change, well-tested area, narrow blast radius
  - Med: touches shared code or untested paths
  - High: touches C-Classes, core flows, or DB schema with downstream consumers
- **Overall confidence** -- Single subjective rating informed by the four dimensions above. If any one dimension is Low (or Regression risk is High), Overall should generally be Med or Low.

## Risks / Unknowns

A short bullet list of the specific things that drove any non-High rating. Keep each bullet to one line. If there are none, omit the bullets but keep the heading present.
