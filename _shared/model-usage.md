---
name: model-usage
description: Cursor included-plan model policy — which model to use for plans, tasks, and subagents. Claude Code sessions use adapters/claude/model-usage.md instead.
keywords: model usage, Grok, Composer, Auto, Other Models, plan model, subagent model, cost policy, included plan
---

# Cursor Model Usage (Team Cost Policy)

Leadership directive: keep Cursor on the **included** plan. Plans get the best included model;
day-to-day tasks scale by difficulty; subagents stay on included Composer. Break big work down
instead of burning Other Models.

## Plan buckets (Cursor → Settings → Plan & Usage)

| Bucket | Examples | When you hit the limit |
|---|---|---|
| **Cursor Models** (included) | Auto, **Cursor Grok 4.5**, **Composer 2.5** | Extra usage can spill into Other Models / on-demand |
| **Other Models** (on-demand when exhausted) | Claude, GPT, Gemini, etc. | Every request bills on-demand spend |

## How to pick a model

| Work | Model | Why |
|---|---|---|
| **Plans** (Plan mode, ticket plans) | **Cursor Grok 4.5** (highest included) | Plans are the highest-leverage artifact — use the best model still inside the plan |
| **Tasks** (implement / verify / PR) | **By difficulty** — Auto / Composer for easy; Grok only when hard | Save included quota for planning and hard slices |
| **Subagents** (`Task` fan-out) | **Composer 2.5** (`composer-2.5-fast`) | Highest included Composer; non-charged bucket for parallel work |
| **Other Models** | Only if **you** choose after being informed | You handle any manager/cost-owner approval |

### Task difficulty guide

- **Low** — renames, wiring, single-file, routine tests → Auto or Composer 2.5
- **Medium** — multi-file slice, focused bug, one repo → Auto; Grok if stuck
- **High** — tricky legacy/C-Class, hard root-cause → Grok 4.5
- **Too big for these** → **split the task** (smaller subagent functions / plan slices). Do not jump to Other Models to paper over a too-large task.

Plans must tag each Work Plan step `[low]|[med]|[high]` so implementation can follow this table
without re-judging from scratch. See [ticket-plan-output.md](ticket-plan-output.md).

**Chat phases:** `/start-ticket` plans **and builds** in one chat (branch mode default). Open a new chat only for `/complete-task`. `--worktree` is the three-chat opt-in (`/implement` in the ticket window). Do not debug local stacks in those threads.

## For agents

Enforced always-on by: [../rules/model-usage.mdc](../rules/model-usage.mdc).

- Plans → Grok 4.5
- Work Plan steps → tagged difficulty; parent task follows the tag
- Subagents → Composer 2.5 only
- If Other Models would help → briefly inform the user; they decide
- Closeout → score Efficiency / Contextualization / Cost·tokens ([task-retrospective.md](task-retrospective.md))
