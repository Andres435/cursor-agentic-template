---
name: ticket-router
description: Classifies a ticket up front and emits a compact work manifest so the orchestrator loads only relevant policy docs, sets up the right repos, and parallelizes safe steps via subagent functions. Use as the first step of start-ticket after ticket fetch.
keywords: router, classifier, manifest, workType, affectedRepos, docSet, priorFindings, parallelPlan, mode, profile
---

# Ticket Router (Classifier)

## Purpose

Turn a ticket into a small, durable **work manifest** that drives the rest of the session. The
manifest is the routing table the orchestrator obeys so it stops indiscriminately reading every
`_shared` doc, provisions only the affected repos, and knows which steps can fan out to subagent
functions.

This is the "function classifier": one cheap up-front decision that shrinks orchestrator context
and enables the multi-agent flow.

## When To Run

- As the **first step** of [../../commands/start-ticket.md](../../commands/start-ticket.md), immediately
  after ticket fetch and required-field gate, before broad code search or branch/worktree provisioning.
- Re-run (refresh) when scope changes materially (a new repo becomes affected, work type changes).

## Inputs

- The fetched ticket (title, description, type, acceptance criteria, tags).
- `profile.json` — repo list, dependency order, specialists, `ticketSystem`, `worktreeSupported`.
- Prior closeouts via [references/closeout-search.md](references/closeout-search.md) /
  [../../plans/closeout-index.md](../../plans/closeout-index.md) (compact `priorFindings` only).

## Classification Axes

Fill each axis from the ticket context and `profile.json`. Do not guess repos you cannot justify.

- `mode`: `branch` (default) | `worktree` (caller passed `--worktree`). Decides where every later
  command works and whether planning and implementation share one chat. See
  [../../_shared/ticket-artifacts.md](../../_shared/ticket-artifacts.md#ticket-mode).
- `workType`: `bug` | `feature` | `spike` | `refactor`. Map ticket type to one of these.
- `affectedRepos[]`: repos in dependency order from `profile.json` that this ticket touches.
  Mark any repo not checked out locally as `{ "repo": "...", "local": false }`.
- `integration`: a domain/integration tag from `profile.json` integrations, or `none`. Set
  `environmentCard` to the matched card path under `environments/` (or `null`).
- `specialists[]`: subset of the `profile.json` specialists list needed for implementation.
- `adrIndex`: path to the ADR index if the project has one and the affected repo uses it, else `null`.
- `featureFlag`: the flag name when the ticket is gated by one, or `null`.
- **Session timestamps.** Write `startedAtUtc` (current UTC ISO-8601), `completedAtUtc` /
  `reopenedAtUtc` / `reclosedAtUtc` as `null`, `timezone` (default `America/Los_Angeles`).
  `/complete-task` fills the close fields.

## Doc Set Selection (token discipline)

Emit `docSet[]` = only the `_shared` slices this ticket actually needs, loaded at the step that
needs them — not a reading list for intake.

- Always on start-ticket: ticket intake reference, [../../_shared/ticket-plan-output.md](../../_shared/ticket-plan-output.md).
- Include workspace-context and cross-repo docs **only** when `affectedRepos` has 2+ repos or
  `integration != none`. Always-on stubs already cover single-repo work.
- `workType` selects the plan shape: bug → `references/bug-fix.md`; feature → `references/feature-plan.md`;
  spike → `references/tech-spike.md`; refactor → `commands/review-changes.md`.
- Include `_shared/adr-policy.md` **only** when `adrIndex` is non-null.
- Include `_shared/test-verification.md` whenever code changes are expected.
- Include the matched `environmentCard` whenever one is matched.
- **Prior closeouts:** follow [references/closeout-search.md](references/closeout-search.md). Run
  `Search-CloseoutMemory.ps1` (or grep `plans/closeout-index.md`) and set `priorFindings[]` (max 8).
  Do not put closeout files in `docSet`.

## Parallel Plan

Emit `parallelPlan` naming the [../../_shared/subagent-functions.md](../../_shared/subagent-functions.md)
calls safe to fan out:

- `scope`: omit by default. One `explore-repo` per candidate repo/area only when repos are ambiguous.
- `branchSetup`: one `branch-setup` per affected local repo (independent git repos).
- `verify`: one `verify-repo` per affected repo at closeout.
- `review`: one `review-diff` per affected repo at closeout.

Sequential-only: cross-repo implementation follows dependency order; commits, pushes, and PR
creation stay on the single approved path.

## Output

Write the manifest to `.cursor/plans/<PREFIX><number>-manifest.json` (ticket-keyed):

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
  "startedAtUtc": "2026-09-07T00:00:00Z",
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
    ".cursor/skills/workflow/start-ticket/references/feature-plan.md",
    ".cursor/_shared/test-verification.md"
  ],
  "parallelPlan": {
    "branchSetup": ["app"],
    "verify": ["app"],
    "review": ["app"]
  }
}
```

Then post a **one-line** chat summary (work type, mode, repos, integration, specialists) and point
to the manifest path. Do not dump the full manifest into chat.

`worktreeRoot` is `<worktrees-root>/<ticket>` in worktree mode and `null` in branch mode. Callers
ask `Resolve-TicketRoot.ps1` rather than reading it directly.

## Guardrails

- Read-only apart from the manifest itself. The router never commits, pushes, or provisions worktrees.
- Keep the manifest small and durable. `priorFindings` is **past** ticket memory (compact), not
  current-ticket discoveries (those go to Deviations or the ledger/index at closeout).
- When repos or integration are ambiguous, list the best candidates and ask the user.
