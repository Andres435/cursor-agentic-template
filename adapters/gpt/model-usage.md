---
name: gpt-model-usage
description: Model tiers mapped to GPT selectors for a Cursor chat whose picker is a GPT model. Replaces the Composer lane map in adapters/cursor/model-usage.md for that chat.
---

# GPT Model Usage (Cursor)

Use this file when the Cursor picker is a GPT model. Tiers and routing rules stay in
[_shared/model-routing.md](../../_shared/model-routing.md). Deep is the GPT model selected in the
picker and stays inline. Do not send those lanes to Composer, and do not ask the user to switch
to a Grok model.

## Tiers

| Tier | `Task` `model` | Used for |
|---|---|---|
| `fast` | `gpt-5.6-sol-medium` | `[low]` steps; explore-repo, why-repo, branch-setup, pr-feedback-fetch, verify-repo |
| `standard` | `gpt-5.6-sol-medium` | `[med]` steps; review-diff, peer-review-pr — the Task list had one GPT selector when checked, so fast and standard share it |
| `deep` | **The chat's selected GPT model, inline only** | plans, `[high]` steps, second-opinion reviewer, architect deep candidate, blast-radius |
| `frontier` | a GPT model the user names | only when the user asks for it in this chat |

**`deepLane: inline`** — deep and `[high]` run on the picker's GPT model. Never dispatched.

`gpt-5.6-sol-medium` is the GPT selector on the Cursor `Task` model list (checked 2026-09-25).
`/doctor --lanes` prints the list again; copy the selector from that list when it changes. If the
list has more than one GPT selector, fast takes the smaller one and standard takes the other, and
this table is updated with the date. Deep is never dispatched.

Every `Task` passes `model` from the tier. A lane whose first line is `Auto`, `inherit`, or a
non-GPT family is discarded. If fast or standard comes back as Auto, say so once and run that step
inline on the selected GPT model. Do not substitute Composer.
