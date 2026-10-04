---
name: start-ticket
description: Chat 1. Plan and build. Branch mode stays in this chat; worktree hands off to /implement.
keywords: start ticket, intake, manifest, branch mode, worktree, plan mode, approval, implement
icon: rocket
color: brand
---

# Start Ticket

Read and execute [playbooks/start-ticket.md](playbooks/start-ticket.md) now. Do not ask for
confirmation before reading the playbook.

## Quick reference

```text
/start-ticket TICKET-42 bug|feature|spike [--worktree]
```

**Branch mode** (default): plan *and* build in this chat; `/review-changes` then `/complete-task` in new chats.
**Worktree mode** (`--worktree`): plan here, build via `/implement` — only if `profile.worktreeSupported`.
