---
name: model-usage
description: Cursor included-plan model policy — tiers (fast/standard/deep/frontier) mapped to Cursor models for plans, tasks, and subagents, the subagent-function role map, and how engineering mode is appended per chat. Claude Code sessions use adapters/claude/model-usage.md instead.
keywords: model usage, tier, fast, standard, deep, frontier, deepLane, engineering mode, Grok, Composer, Auto, Other Models, plan model, subagent model, subagent_type, Custom Mode, cost policy, included plan
---

# Cursor Model Usage (Team Cost Policy)

Included Cursor models are the efficient default for fast and standard lanes. Deep dispatches to
the listed Grok selector. A GPT picker uses
[../gpt/model-usage.md](../gpt/model-usage.md) instead of this table. Picking
another family is allowed; it is not a stop. Any other family with no adapter runs inline; say once
that fast and standard have no selector in that family yet.

## Plan buckets (Cursor → Settings → Plan & Usage)

| Bucket | Examples | When you hit the limit |
|---|---|---|
| **Cursor Models** (included) | Auto, Cursor Grok, **Composer 2.5** | Extra usage can spill into Other Models / on-demand |
| **Other Models** (on-demand when exhausted) | Claude, GPT, Gemini, etc. | Every request bills on-demand spend |

## Tier map (Cursor, included-model chat)

Use this table when the picker is a Cursor Grok or Composer model. A GPT picker uses the GPT adapter.

| Tier | Cursor model | Used for |
|---|---|---|
| `fast` | `composer-2.5-fast` | `[low]` steps; explore-repo, branch-setup, pr-feedback-fetch, verify-repo |
| `standard` | `composer-2.5-fast` | `[med]` steps; review-diff, peer-review-pr — Cursor's included bucket has one Composer, so fast and standard share it |
| `deep` | `grok-4.7-high-fast` when that selector is on this session's `Task` list | plans, `[high]` steps, second-opinion reviewer, architect deep lane, blast-radius |
| `frontier` | Another model the user names | only when the user says so in chat; they own any cost approval |

### Task `model` selectors

Pass the exact selector from this session's `Task` model list — never guess a slug.
`composer-2.5-fast` is the known Composer selector. `grok-4.7-high-fast` is the known Grok selector.

**`deepLane: dispatch`** — deep and `[high]` go to a `grok-4.7-high-fast` lane; inline when this
chat already runs on that Grok. If that selector is not on the session's `Task` list, ask the user
to pick a model. Do not invent a slug. Fast and standard stay on `composer-2.5-fast`.

**Lane probe, 2026-10-04:** fast and standard on `composer-2.5-fast` reported Composer. Deep on
`grok-4.7-high-fast` reported Grok 4.7 — honored. The 24 Sep result (that selector reported Auto)
is retired. `/doctor --lanes` dispatches deep. A reply of Auto is still a fail: record the tier
unhonored and leave deep inline until a later probe honors it.

**Never Auto.** Auto is not a selection: if the picker is Auto or the model cannot be told, ask the
user to pick a model before deep work, and do not name one. Every lane's reply starts with
`model:`; one that says Auto is discarded. To re-test after a plan change, run
`/doctor --lanes --retest-inline`: it prints the `Task` tool's accepted `model` values.

## Subagent roles → `Task` `subagent_type`

| Function | `subagent_type` |
|---|---|
| `explore-repo` | `explore` |
| `branch-setup` | `shell` |
| `verify-repo` | `generalPurpose`, or `dotnet-specialist` / `vb-legacy-specialist` by repo (no `shell` type — WI22783) |
| `review-diff`, `peer-review-pr` | `code-reviewer`; if `Task` rejects it, `generalPurpose` with the code-reviewer prompt (WI17154) |
| `pr-feedback-fetch` | `generalPurpose` |

## For agents

Always-on stub: [../../rules/model-usage.mdc](../../rules/model-usage.mdc). Contract:
[model-routing.md](../../_shared/model-routing.md). Verbs: [harness-verbs.md](../../_shared/harness-verbs.md).

- Every `Task` names `model` from its role or step-tag tier — never omit it; an omitted `model`
  inherits the chat.
- Engineering mode: append `/engineering-mode`, or pin the `engineering-mode` skill as a Custom
  Mode (`/` → engineering-mode → Alt+Enter / **Use as Mode**). × on the chip or "exit engineering
  mode" turns it off. Without it, the chat plans and builds inline on its own model.
- A slash command attaches its playbook to one message. For a long ticket, enable the command in
  Custom Mode (Option+Enter on Mac) so it stays active across the chat.
- Other Models (frontier) → only after the user chooses.
