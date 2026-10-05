---
name: start-ticket
description: Chat 1. Plan and build. Branch mode stays in this chat; worktree hands off to /implement.
keywords: start ticket, intake, manifest, branch mode, worktree, plan mode, approval, implement
disable-model-invocation: true
icon: rocket
color: brand
---

# Start Ticket

Start a ticket from the project's ticket system, classify it into a work manifest, set up branches (or per-ticket worktrees with --worktree), build the approved plan, and in branch mode implement it in the same chat.

Read and execute [playbooks/start-ticket.md](playbooks/start-ticket.md) now. Do not ask for confirmation before reading the playbook.

## Quick reference

```text
/start-ticket TICKET-42 bug|feature|spike [--worktree]
```

When `profile.worktreeSupported` is true, ask whether this ticket lives in the **main tree** or a **worktree** before any branch is created. Skip the question only when this same message already passes `--worktree` or explicitly says main tree / branch mode. `profile.defaultMode` does not skip it. When worktrees are not supported there is nothing to ask: branch mode. A **spike** does not ask and does not create a branch: record `mode: investigate` and read the clones as they are.

**Main tree:** plan *and* build in this chat; run `/review-changes` then `/complete-task` in new chats.
**Worktree:** plan here, build in the ticket window via `/implement`.

Plan shapes → [references/bug-fix.md](references/bug-fix.md),
[references/feature-plan.md](references/feature-plan.md),
[references/tech-spike.md](references/tech-spike.md).
