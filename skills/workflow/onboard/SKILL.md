---
name: onboard
description: Walk a new developer through machine setup and workspace initialization for an agentic template project.
keywords: onboard, machine setup, new developer, install, bootstrap, initialize, customize
---

# /onboard — New Machine Setup

Walk the user through setting up their machine for the agentic template project. Read and follow
[CUSTOMIZE.md](../../../CUSTOMIZE.md) to guide the customization conversation, then run the
initialization script.

## When to use

- First time cloning the template
- After renaming the project (`profile.json` id, displayName)
- When `/doctor` reports failures

## What this does NOT do

- Does not create worktrees (template default is branch mode).
- Does not install language-specific dependencies — those are per-project.

## Steps

1. If `profile.json` `id` is still `customize-me`, walk [CUSTOMIZE.md](../../../CUSTOMIZE.md)
   **top to bottom** and fill every required blank (`profile.json`, `environments/local-dev.md`,
   `agents/fullstack-specialist.md`). Do not start a ticket until those are filled.
2. If the profile is already customized, skip the questionnaire — run the init script and `/doctor`.
3. **Run the initialization script**:
   ```powershell
   # From the repo root:
   .\.cursor\scripts\machine\Initialize-WorkflowMachine.ps1
   ```
4. After running the script, run `/doctor` to confirm the workspace is healthy.
5. If `/doctor` shows failures, walk through the specific fix listed.

## Output

After completing setup, show a one-line summary:
```text
Machine setup done — run /doctor to confirm.
```
