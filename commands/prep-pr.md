---
name: prep-pr
description: Prepare changed repositories for PR submission. Use when generating commit messages, PR descriptions, testing summaries, SonarQube notes, confidence summaries, or cross-repo PR references.
keywords: PR, commit message, PR description, ADO write-back, approval package, Code Review transition
---

# Prepare Pull Requests

Full instructions (commit → push → PR → ADO write-back): [../skills/workflow/prep-pr/SKILL.md](../skills/workflow/prep-pr/SKILL.md).

Read and execute that skill now. Do not ask for confirmation before reading the skill.

## Quick reference

```text
/prep-pr WI22132
```

Called from `/complete-task` once the user approves the package. Also usable standalone when the
user says "create the PR" or "submit the PR".

**Draft mode** (default): inventory, draft, approval package, wait.
**Execute mode**: use only when the user already approved the package from `complete-task`.
