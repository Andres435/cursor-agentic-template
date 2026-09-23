---
name: ticket-workflow
description: Phase-to-owner map of the ticket lifecycle. Reference only — start-ticket and complete-task own the mechanics. If this file and a command disagree, the command wins.
keywords: ticket lifecycle, end-to-end, workflow map, phases, narrative
---

# Ticket Workflow (phase map)

This file is a **read-only map**. It names the doc that owns each phase. Do not execute steps from
here; invoke the commands directly. If anything here contradicts a command or skill, that file wins.

Setup and context live in **overlay blanks** (`profile.json`, `CUSTOMIZE.md`, `environments/`,
`agents/`). Fill those once via `/start-new-project`, then `/onboard` for the machine.
Every command below then reads the profile — it does not re-interview the user for stack or repos.

## Lifecycle overview

```mermaid
flowchart LR
  A["/start-ticket"] --> B["Plan mode"]
  B --> C["Approved plan persisted"]
  C --> D["Branch mode: build in same chat"]
  C --> E["Worktree mode: /implement"]
  D --> F["/review-changes (new chat)"]
  E --> F
  F --> G["/complete-task (new chat)"]
  G --> H["/prep-pr (on approval)"]
  H --> I["/address-pr-comments (later)"]
```

## Phase owners

| Phase | What triggers it | Command / skill that owns the mechanics |
|---|---|---|
| Intake + classify | `/start-ticket` | [commands/start-ticket.md](../../../commands/start-ticket.md) → [ticket-router/SKILL.md](../ticket-router/SKILL.md) |
| Branch / worktree setup | Step 5 of start-ticket | `branch-setup` via [subagent-functions.md](../../../_shared/subagent-functions.md) |
| Plan (Engineering Decisions + Work Plan) | Step 6 of start-ticket | [bug-fix.md](../start-ticket/references/bug-fix.md) · [feature-plan.md](../start-ticket/references/feature-plan.md) · [tech-spike.md](../start-ticket/references/tech-spike.md) |
| Build (branch mode) | After plan approval | Same chat; [implement/PLAYBOOK.md](../implement/PLAYBOOK.md) steps 3–6 |
| Build (worktree / resume) | `/implement` | [commands/implement.md](../../../commands/implement.md) → [implement/PLAYBOOK.md](../implement/PLAYBOOK.md) |
| Local stack | `/start-stack` | [commands/start-stack.md](../../../commands/start-stack.md); rails: [runtime-verify.md](../../../_shared/runtime-verify.md) |
| Review | `/review-changes` (new chat) | [commands/review-changes.md](../../../commands/review-changes.md) → [review-changes/PLAYBOOK.md](../review-changes/PLAYBOOK.md) |
| Closeout | `/complete-task` (new chat) | [commands/complete-task.md](../../../commands/complete-task.md) → [complete-task/PLAYBOOK.md](../complete-task/PLAYBOOK.md) |
| PR / tracker write-back | `/prep-pr` (after approval) | [commands/prep-pr.md](../../../commands/prep-pr.md) → [prep-pr/PLAYBOOK.md](../prep-pr/PLAYBOOK.md) |
| PR feedback | `/address-pr-comments` | [commands/address-pr-comments.md](../../../commands/address-pr-comments.md) → [address-pr-comments/PLAYBOOK.md](../address-pr-comments/PLAYBOOK.md) |
| Fresh-chat hydrate | First step of implement, complete-task, address-pr-comments | [ticket-context-load/SKILL.md](../ticket-context-load/SKILL.md) |
| New product | `/start-new-project` | [commands/start-new-project.md](../../../commands/start-new-project.md) → [start-new-project/SKILL.md](../start-new-project/SKILL.md) |
| New clone / machine | `/onboard` | [onboard/SKILL.md](../onboard/SKILL.md) + [CUSTOMIZE.md](../../../CUSTOMIZE.md) |

## Contracts that override prose

| Question | Authoritative source |
|---|---|
| Which files each phase must produce | [_shared/ticket-artifacts.md](../../../_shared/ticket-artifacts.md) |
| Chat output caps | [_shared/severity-and-output.md](../../../_shared/severity-and-output.md) |
| Plan structure and Deviations | [_shared/ticket-plan-output.md](../../../_shared/ticket-plan-output.md) |
| Engineering Decisions shape | [_shared/engineering-decisions.md](../../../_shared/engineering-decisions.md) |
| Cross-repo order | [_shared/cross-repo-workflow.md](../../../_shared/cross-repo-workflow.md) |
