---
name: prep-pr
description: Prepare changed repositories for PR submission after an approved complete-task package.
keywords: PR, commit message, PR description, tracker write-back, approval package
---

# Prepare Pull Requests

Full instructions: [../skills/workflow/prep-pr/PLAYBOOK.md](../skills/workflow/prep-pr/PLAYBOOK.md).

Read and execute that playbook now.

```text
/prep-pr TICKET-42
```

**Draft** (default): inventory and wait. **Execute**: only after the user approved the package.
Tracker write-back runs only when `profile.ticketSystem` is not `none`.
