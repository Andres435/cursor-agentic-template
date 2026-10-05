---
name: prep-pr
description: Only after you approve the complete-task package. Commit, push, PR, and tracker write-back.
keywords: PR, commit message, PR description, tracker write-back, approval package, review transition
disable-model-invocation: true
icon: git-pull-request
color: purple
---

# Prepare Pull Requests

Full instructions (commit → push → PR → tracker write-back): [playbooks/prep-pr.md](playbooks/prep-pr.md).

Read and execute that playbook now. Do not ask for confirmation before reading it.

## Quick reference

```text
/prep-pr <ticket>
```

Called from `/complete-task` once the user approves the package. Also usable standalone when the
user says "create the PR" or "submit the PR".

**Draft mode** (default): inventory, draft, approval package, wait.
**Execute mode**: use only when the user already approved the package from `complete-task`.

**PR body:** a few sentences on what changed and why, plus the test plan. Do not paste a full
changelog, and do not append a generated-by trailer. The rule lives in step 3 of
[playbooks/prep-pr.md](playbooks/prep-pr.md).
