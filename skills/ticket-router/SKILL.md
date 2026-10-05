---
name: ticket-router
description: Classifies a ticket up front and emits a compact work manifest so the orchestrator loads only relevant policy docs, sets up the right repos, and parallelizes safe steps via subagent functions. Use as the first step of start-ticket after ticket fetch.
keywords: router, classifier, manifest, workType, affectedRepos, docSet, priorFindings, parallelPlan, mode, profile
icon: route
color: purple
---

# Ticket Router (Classifier)

## Purpose

Turn a ticket into a small, durable **work manifest** that drives the rest of the session. Axes
come from **`profile.json` first** — repos, specialists, ticket prefix, default mode — then from
the fetched ticket. Do not interview the user for values the profile already holds.

## When To Run

- As the **first step** of [../start-ticket/SKILL.md](../start-ticket/SKILL.md),
  immediately after ticket fetch, before broad code search or branch/worktree provisioning.
- Re-run (refresh) when scope changes materially.

## Inputs

- **[../../profile.json](../../profile.json)** — read once.
- The fetched ticket (title, description, type, acceptance criteria, tags).
- Prior closeouts via [references/closeout-search.md](references/closeout-search.md).

## Classification Axes

Fill each axis from the ticket context and `profile.json`. Do not guess repos outside `profile.repos`.

- `mode`: `profile.defaultMode` unless the caller passed `--worktree` and
  `profile.worktreeSupported` is true.
- `workType`: `bug` | `feature` | `spike` | `refactor`. Each has a plan template (see Doc Set Selection).
- `affectedRepos[]`: subset of `profile.repos` in `profile.dependencyOrder`. Mark any repo not
  cloned locally as `{ "repo": "...", "local": false }`.
- `integration`: one of `profile.integrations` or `none`. `environmentCard` = matched path under
  `environments/` (or `null`).
- `specialists[]`: subset of `profile.specialists`.
- `adrIndex`: copy `profile.adrIndex` when that repo is in `affectedRepos`, else `null`.
- `featureFlag`: the flag name when the ticket is gated by one, or `null`.
- `baseBranch`: `profile.baseBranchDefault`.
- **Session timestamps.** Write `startedAtUtc` (current UTC ISO-8601); close fields `null`;
  `timezone` default `America/Los_Angeles`.

## Doc Set Selection (token discipline)

Emit `docSet[]` = only the slices this ticket may load, loaded at the step that needs them.

- Always: ticket intake reference, [../../_shared/ticket-plan-output.md](../../_shared/ticket-plan-output.md).
- Include [../../_shared/cross-repo-workflow.md](../../_shared/cross-repo-workflow.md)
  **only** when `affectedRepos` has 2+ repos or `integration != none`.
- `workType` selects the plan shape, the work-type template: bug → `skills/start-ticket/references/bug-fix.md`;
  feature and refactor → `skills/start-ticket/references/feature-plan.md` (refactor uses its
  Refactor section); spike → `skills/start-ticket/references/tech-spike.md`.
- Include `_shared/adr-policy.md` **only** when `adrIndex` is non-null.
- Include `_shared/test-verification.md` whenever code changes are expected.
- Include `_shared/engineering-decisions.md` on start-ticket (the plan step needs it).
- Include the matched `environmentCard` whenever one is matched.
- Prior closeouts: see the next section. Never put closeout files in `docSet`.

## Prior closeouts

`Search-CloseoutMemory.ps1` **once per affected repo** with `-MaxResults 4` — one multi-repo call
folds every repo name into one score and pulls unrelated rows — plus one `integration`-only pass when
`integration` ≠ `none`. Union, dedupe by ticket id, cap **8** `priorFindings`. `/start-ticket`
dispatches it in its step 5 fan-out: write `priorFindings: []` at step 3, then update the manifest
when the results land. Script failure: [references/closeout-search.md](references/closeout-search.md).

A row describing a call that went wrong last time is an Engineering Decisions candidate
([../../_shared/engineering-decisions.md](../../_shared/engineering-decisions.md)), not just
background.

## Parallel Plan

- `scope`: one `explore-repo` per affected **local** repo. Skip only when there is exactly one
  local repo **and** the ticket already names the file. Parent checks packets — drop empty;
  flag contradictions as Engineering Decisions candidates.
- `branchSetup`: one `branch-setup` per affected local repo.
- `verify`: one `verify-repo` per affected repo at closeout.
- `review`: one `review-diff` per affected repo at closeout **unless**
  `Get-ReviewSkip.ps1` reports `skip: true` for that repo.

Sequential-only: cross-repo implementation follows `profile.dependencyOrder`; commits, pushes, and
PR creation stay on the single approved path.

## Output

Write `.cursor/plans/<PREFIX><number>-manifest.json`:

```json
{
  "workItemId": "TICKET-42",
  "workType": "feature",
  "mode": "branch",
  "ticket": {
    "title": "Add user export to CSV",
    "type": "feature",
    "state": "In Progress"
  },
  "startedAtUtc": "2026-09-18T00:00:00Z",
  "completedAtUtc": null,
  "reopenedAtUtc": null,
  "reclosedAtUtc": null,
  "timezone": "America/Los_Angeles",
  "affectedRepos": [
    { "repo": "app", "local": true }
  ],
  "integration": "none",
  "environmentCard": null,
  "specialists": ["fullstack"],
  "adrIndex": null,
  "featureFlag": null,
  "baseBranch": "main",
  "priorFindings": [],
  "worktreeRoot": null,
  "docSet": [
    ".cursor/_shared/ticket-plan-output.md",
    ".cursor/skills/start-ticket/references/feature-plan.md",
    ".cursor/_shared/engineering-decisions.md",
    ".cursor/_shared/test-verification.md"
  ],
  "parallelPlan": {
    "scope": ["app"],
    "branchSetup": ["app"],
    "verify": ["app"],
    "review": ["app"]
  }
}
```

Then post a **one-line** chat summary. Do not dump the full manifest.

## Guardrails

- Read-only apart from the manifest. Never commit, push, or provision worktrees.
- When repos or integration are ambiguous **within** `profile.repos`, list candidates and ask.
  Do not ask the user to re-fill `profile.json`.
