---
name: worktree-handoff
description: Worktree-mode-only steps of /start-ticket — provisioning the ticket worktrees, the runtime heal, and the final handoff message to /implement in the ticket worktree chat.
keywords: worktree, ticket worktree, handoff, paste block, runtime warmup, Set-ActiveStack
---

# Worktree handoff

Loaded by [../playbooks/start-ticket.md](../playbooks/start-ticket.md) only when `mode` is
`worktree`. Branch and investigate mode never read it.

## Provision (step 4)

- Needs `profile.worktreeSupported`. If `scripts/New-TicketWorktree.ps1` (or `scripts/worktree/`) is
  absent, stop and say worktrees are not installed in this profile. The overlay's
  [../../../environments/worktrees.md](../../../environments/worktrees.md) says where worktrees live
  and how the provisioning script is called.
- The script adds one git worktree per affected repo on branch `<ticket>` from
  `origin/<baseBranch>`. Repos not cloned locally are skipped — name them in the startup line.
- **This chat stays rooted at the workflow root** and never edits worktree source files — not after
  `exit-plan`, not on an IDE build button. Implementation is [../../implement/SKILL.md](../../implement/SKILL.md)
  in a chat rooted at the ticket worktree ([how, per IDE](../../../adapters/README.md#open-a-ticket-worktree)).
- **One app stack at a time:** if this ticket will run the local stack, claim it with
  `scripts/runtime/Set-ActiveStack.ps1 -Ticket <ticket>` before any launcher.

## Runtime heal (step 8)

When the overlay ships `Initialize-TicketRuntime.ps1` (under `scripts/runtime/`), it was started in the
background at step 5 and is awaited after the start gate. It confirms each worktree is on
`<ticket>`, restores dependencies the profile names, and never starts the app or a browser.

## Final message (step 10)

1. `.\.cursor\scripts\ticket\Set-TicketCtxPct.ps1 -Ticket <ticket> -Phase start` — this plan chat only;
   the `/implement` chat is not recorded.
2. The worktree startup message from `ticket-plan-output.md` (loaded at step 6): startup line, then
   the approved Work Plan with its `[low]|[med]|[high]` tags.
3. The paste block from
   [../../../_shared/ticket-artifacts.md](../../../_shared/ticket-artifacts.md#handoff-between-chats) —
   last, with nothing after its closing fence.
