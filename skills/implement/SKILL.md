---
name: implement
description: Fresh chat only. Worktree build, or resume when chat 1 ran out of context. Runs the approved plan in order and stops for review.
keywords: implement, execute plan, worktree window, resume, grounded refinement, deviations, scoped tests
disable-model-invocation: true
icon: hammer
color: blue
---

# Implement

Full instructions (resume / worktree only): [playbooks/implement.md](playbooks/implement.md).

Read and execute that playbook now. Do not ask for confirmation before reading it.

## Quick reference

```text
/implement <ticket>
```

Use this command when:
1. **Worktree mode** — building in the ticket window.
2. **Resuming branch mode** — the `/start-ticket` chat ran out of context.

A spike (`mode: investigate`) resumes here only to finish read-only research on the clones as they
are. Do not create or check out `<ticket>`.

Do **not** use this in the chat that just approved the plan in branch mode — keep building there.

A comment or doc that disagrees with the executable statement is **not** a routine grounded
refinement — stop and ask.
