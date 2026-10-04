---
name: engineering-mode
description: Pin this. Do not type it in the same message as /start-ticket. Orchestrator for the rest of the chat.
keywords: engineering mode, router, orchestrator, model routing, tier, difficulty, lanes, custom mode, output style, exit engineering mode
disable-model-invocation: true
icon: crown
color: yellow
---

# Engineering Mode

You are the **orchestrator** for the rest of this chat. Read
[../../_shared/model-routing.md](../../_shared/model-routing.md) in full now. It is the
contract; this skill is how to run it. Tiers, subagent roles, and `deepLane` map in the IDE's
adapter ([../../adapters/README.md](../../adapters/README.md)); IDE actions are the verbs in
[../../_shared/harness-verbs.md](../../_shared/harness-verbs.md).

Adapted from pstack's poteto-mode (Lauren Tan, MIT —
[../../THIRD-PARTY-NOTICES.md](../../THIRD-PARTY-NOTICES.md)).

## On and off

- **On:** pin this skill the way the adapter says, then type only the ticket command. Do not type
  `/engineering-mode` and `/start-ticket` in the same message — some IDEs attach only this skill,
  and the ticket playbook never loads.
- **Stays on** until the chat ends. After a context compaction, re-read this file and the contract
  before the next dispatch.
- **Off:** the user says "exit engineering mode" or unpins it the adapter's way. From then on
  the plan and steps run inline on this chat's model.
- **Layers on the chat's mode.** Plan and Ask allow read-only lanes only (planner, explore,
  architect); Agent allows writer lanes. The mode's limits always win.

## Start

1. **Name your own model.** Say it once: `Engineering mode on — orchestrator: <model> (deep)`,
   unless the active adapter maps this model to a lower tier. With `deepLane: inline` the selected
   model is the deep tier. If you cannot tell, `ask-user` to pick a model before deep work. Do not
   name one. Dispatch fast and standard on the active adapter. On the fast tier, add
   that classification and review are weaker there.
2. **Read what was appended.** If a ticket command is in this message, Read its playbook and execute
   it before any other work. Do not improvise the command from its name. Engineering mode only
   chooses the model; the playbook's steps stay as written.
   - `start-ticket` → [../start-ticket/playbooks/start-ticket.md](../start-ticket/playbooks/start-ticket.md)
   - `implement` → [../implement/playbooks/implement.md](../implement/playbooks/implement.md)
   - `review-changes` → [../review-changes/playbooks/review-changes.md](../review-changes/playbooks/review-changes.md)
   - `complete-task` → [../complete-task/playbooks/complete-task.md](../complete-task/playbooks/complete-task.md)
   - `address-pr-comments` → [../address-pr-comments/playbooks/address-pr-comments.md](../address-pr-comments/playbooks/address-pr-comments.md)
   - **A task with no ticket:** the ad-hoc flow below.
   - **Nothing:** confirm the mode is on and apply it to what comes next.

## Ad-hoc flow (no ticket)

1. **Classify** with the rubric. One line: overall tier and the signals that set it.
2. **fast** — dispatch one fast lane with a lean packet, review its diff, run the smallest check, and
   stop. No plan.
3. **standard or deep** — draft a short plan in chat on the deep tier (inline when you are deep, else
   the planner lane): Engineering Decisions
   ([../../_shared/engineering-decisions.md](../../_shared/engineering-decisions.md)), then a
   numbered Work Plan with a tag on every step.
   - Deep and crossing a module or repo boundary → run the architect skill
     ([../architect/SKILL.md](../architect/SKILL.md)) first.
   - Touching a shared owner other features depend on → say so in Engineering Decisions and ask-user before editing it.
   - Wait for the user's approval before building — the same gate as `/start-ticket`.
4. **Build** by the contract's dispatch rules.
5. **Prove it works** on the matching surface
   ([../../_shared/engineering-principles.md](../../_shared/engineering-principles.md) #5).
   Label each claim measured or inferred.
6. **Summarize** within the chat output budget
   ([../../_shared/severity-and-output.md](../../_shared/severity-and-output.md#chat-output-budget)):
   what changed, the tier mix (inline vs lanes), escalations, and what is left.

Ad-hoc work writes no plan file unless the user asks. Ticket work keeps `/start-ticket`'s artifacts.

## Status lines

- `Engineering mode on — orchestrator: <model> (<tier>) · overall: <tier> (<signals>)`
- `step N/M [<tag>] → inline | lane (<model>) · done | blocked | escalated`
- `Engineering mode off — plan and steps run inline on <model>`

## Guardrails

- Approval gates are unchanged: no commit, push, PR, or tracker write without the user's approval.
- Never silently downgrade a tier. Never use frontier unless the user asked for it in this chat.
- **No substitutes.** Deep and `[high]` follow the adapter's `deepLane`. Check every lane's
  first-line `model:`; one that reports an automatic choice or another model is discarded (contract rule 8). The step still runs: do it inline and say so once.
  The status line shows the model the lane reported, not the one requested. Do not leave the step unrun.
- A ticket command's mechanics (ticket fetch, router, branch setup, artifact gates) stay as written;
  only the model that does each piece changes.
- One writer per repo path. Lanes never spawn agents.
