---
name: start-ticket
description: Start a ticket from the project's tracker, classify it into a work manifest, set up branches (or worktrees with --worktree), build the approved plan, and in branch mode implement it in the same chat.
keywords: start ticket, intake, manifest, branch mode, worktree, plan mode, approval, implement
---

# Start Ticket

Read and execute [../playbooks/start-ticket.md](../playbooks/start-ticket.md) now. Do not ask for
confirmation before reading the playbook.

## Quick reference

```text
/start-ticket TICKET-42 bug|feature|spike [--worktree]
```

**Branch mode** (default): plan *and* build in this chat; `/review-changes` then `/complete-task` in new chats.
**Worktree mode** (`--worktree`): plan here, build via `/implement` — only if `profile.worktreeSupported`.
