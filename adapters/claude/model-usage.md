---
name: claude-model-usage
description: Model tiers for Claude Code (Anthropic plan). Replaces Cursor Grok/Composer policy when this runtime is active.
---

# Claude Code Model Usage

Use this file **instead of** `rules/model-usage.mdc` and `_shared/model-usage.md` whenever
the agent is Claude Code. Those files are Cursor included-plan policy and do not apply
to an Anthropic subscription.

## Tiers

| Work | Model | Why |
|---|---|---|
| **Plans** (plan mode, `/start-ticket` plan step, bug/feature/spike plans) | **Opus** (highest available on the account) | Plans are the highest-leverage artifact |
| **Tasks** (implement / verify / PR) | **Sonnet** | Default implementation model |
| **Subagents** (plugin specialists, explore, shell) | **Sonnet** | Do not inherit Opus for fan-out |

If a slice is too large, **split it** (smaller subagent functions / plan steps). Do not
silently jump models.

## Claude-specific substitutions

| Cursor instruction | Do this in Claude Code |
|---|---|
| Cursor Plan mode / `SwitchMode` | Claude Code plan mode |
| `model: composer-2.5-fast` on `Task` | Agent tool, model omitted (inherits session Sonnet) |
| Remind user to pick Grok 4.5 | Skip — Opus is selected in this runtime |
| "Other Models" cost warning | Skip — this session is already on the Anthropic plan |

## Subagent-function → Agent-tool mapping

[`_shared/subagent-functions.md`](../../_shared/subagent-functions.md) names Cursor `Task`
`subagent_type` values. Claude Code has a different agent registry — use this table instead:

| Function | Cursor `subagent_type` | Claude Code `Agent` type | Notes |
|---|---|---|---|
| `explore-repo` | `explore` | `Explore` | Read-only search agent. |
| `branch-setup` | `shell` | `general-purpose` | `general-purpose` has Bash access for git ops. |
| `verify-repo` | `shell` | `general-purpose` | Enough for a scoped test run. |
| `review-diff` | `code-reviewer` | `general-purpose` | Adapt as needed. |
| `pr-feedback-fetch` | `generalPurpose` | `general-purpose` | Direct match. |

Dispatch with the `Agent` tool, one call per independent repo/area, batched in a single message
so they run concurrently. Omit `model` so calls inherit the session Sonnet.

All other contract details (fixed inputs, compact return shape, no-commit/push guardrail) in
`subagent-functions.md` apply unchanged; only the dispatch mechanics differ.

Approval gates are unchanged: no commit, push, or PR write except on `/start-ticket`
(state transitions) and what the user approved on `/prep-pr`.
