---
name: address-pr-comments
description: Later, on PR feedback. Compact active PR comments and static-analysis feedback, triage, apply the fixes you accept, verify, and prepare follow-up updates.
keywords: PR comments, threads, triage, Fixed, WontFix, static analysis feedback, reply, thread status
disable-model-invocation: true
icon: message-square
color: orange
---

# Address PR Comments

Full instructions (fetch → triage → fix → update): [playbooks/address-pr-comments.md](playbooks/address-pr-comments.md).

Read and execute that playbook now. Do not ask for confirmation before reading it.

## Quick reference

```text
/address-pr-comments <ticket>
```

Prefer a **new chat** so implementation context is not competing with review context.

Inputs: ticket id, or a single PR URL / `repo PR_NUMBER` for narrow scope.

Logic changes after a prior stack smoke pass stamp `stackSmoke` as **stale** (Untested latest
changes), not Never tested.
