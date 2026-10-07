---
name: claude-model-usage
description: Model tiers (fast/standard/deep/frontier) mapped to Claude models for every Agent call, plus the Claude subagent-type map and deepLane. Each IDE has its own adapters/<ide>/model-usage.md.
---

# Claude Code Model Usage

Use this file **instead of** the Cursor tier map ([../cursor/model-usage.md](../cursor/model-usage.md)).
Tiers and routing rules are harness-neutral in [../../_shared/model-routing.md](../../_shared/model-routing.md);
verbs in [../../_shared/harness-verbs.md](../../_shared/harness-verbs.md). This file maps them to Claude.

## Tiers

| Tier | `Agent` `model` | Used for |
|---|---|---|
| `fast` | `haiku` | `[low]` steps; explore-repo, why-repo, branch-setup, pr-feedback-fetch, verify-repo |
| `standard` | `sonnet` | `[med]` steps; review-diff, peer-review-pr |
| `deep` | `opus` | plans, `[high]` steps, second-opinion reviewer, architect deep lane, blast-radius |
| `frontier` | `fable` | only when the user asks for it in chat |

**`deepLane: dispatch`** — deep and `[high]` go to an `opus` lane; inline when this chat already runs on `opus`.

- Every `Agent` call passes `model` from the tier of its role or step tag. Precedence: the
  `Agent` `model` parameter beats agent frontmatter, which beats the `CLAUDE_CODE_SUBAGENT_MODEL`
  env var (set it to `sonnet`), which beats this chat's model. Still pass it, and
  discard a lane whose first-line `model:` names a substitute (a blocked model falls back silently).
- `Agent` has no effort parameter; effort-pinned lanes are deferred.
- Planner lane (engineering mode, orchestrator not on `opus`): the built-in `Plan` agent with
  `model: "opus"`; send revisions back to the same agent with `SendMessage`.
- Engineering mode: `/agentic:engineering-mode`, or select the **agentic:Engineering mode** output style
  (`/output-style`, or the desktop Code tab's output-style preference); switch back to Default or
  say "exit engineering mode" to turn it off. Ticket commands load the tier contract on their own. Pin this for ad-hoc work or a long chat.
- Too large for a tier → split it; escalation is one tier up and logged, never down.
- `/agentic:doctor --lanes` extra check: `~/.claude/settings.json` `env.CLAUDE_CODE_SUBAGENT_MODEL` is
  `sonnet`. Fail with: `unrouted subagents inherit the chat model — see adapters/claude/README.md`.

## Claude-specific notes

Verb → tool map: [harness-verbs](../../_shared/harness-verbs.md).

| Shared doc says | Do this in Claude Code |
|---|---|
| `dispatch(function, tier)` | `Agent` with the role's tier model from the table above — never omit `model` |
| Ask the user to pick a model | Skip — this runtime has no Auto picker; deep is `opus` |
| `frontier` tier | `fable` only on explicit user request |
| Pin engineering mode | **agentic:Engineering mode** output style |

## Subagent-function → Agent-tool mapping

[`_shared/subagent-functions.md`](../../_shared/subagent-functions.md) names a role per function.
`dispatch` maps each to an `Agent` `subagent_type`:

| Function | `Agent` `subagent_type` | Tier | Notes |
|---|---|---|---|
| `explore-repo` | `Explore` | fast | Read-only search; matches "where does X live". |
| `why-repo`, `branch-setup` | `general-purpose` | fast | No dedicated shell agent; Bash for git log/fetch. |
| `verify-repo` | `general-purpose`, or a stack specialist agent when the profile defines one | fast | Prefer the specialist only when the stack needs it. |
| `review-diff` | `agentic:code-reviewer` if your overlay adds one, else `general-purpose` with the review-changes prompt | standard (+ deep second opinion when the plan has a `[high]` step) | Never skip the review. |
| `pr-feedback-fetch` | `general-purpose` | fast | Direct match. |
| `peer-review-pr` | same as `review-diff` | standard | Coworker PR comments; read-only; no severity labels. |

One `Agent` call per independent repo/area, batched in a single message so they run concurrently.
**Pass `model` from the Tier column** — an omitted `model` inherits this chat's model. All other
contract details in `subagent-functions.md` apply unchanged.

Approval gates are unchanged: no commit, push, PR, or tracker State write except
`/agentic:start-ticket` (to In Progress), what the user approved on
`/agentic:prep-pr`, and approved `/agentic:peer-review` inline comments.
