---
name: start-stack
description: Start the local app stack for a ticket via the command in profile.json stacks.startCommand. Low-token — runs the script only.
keywords: local stack, start apps, start-stack, dev server, profile startCommand
---

# Start Stack

Start the local dev stack for a ticket. Do **not** fetch the ticket, read env cards, or explore
the codebase — the start command resolves the stack from `profile.json`.

## Invocation examples

- `/start-stack TICKET-42`
- `/start-stack` (uses current active ticket if set)

## Workflow

1. Read `profile.stacks.startCommand` from `profile.json`.
2. Run:
   ```powershell
   .\.cursor\scripts\runtime\Start-TicketStack.ps1 -Ticket <id>
   ```
   Or, for non-PowerShell setups, exec `profile.stacks.startCommand` directly.
3. Report exit status and any printed URLs.
4. **If failed**: stop the process, retry **once** with the same command.
   Still fails → stop and report. Do not diagnose ports or rebuild.

## Guardrails

- Do not read env cards or manifests — the start script does that.
- Finished when URLs print or the one retry still fails. Further debug → new chat.
- Do not start a second stack while another ticket owns it unless the user passed `-Force`.
