---
name: start-stack
description: Local apps. Not a chat phase. Start the stack named in profile.json.
keywords: local stack, start apps, services, preset, active stack
disable-model-invocation: true
icon: terminal
color: green
---

# Start Stack

Start the local stack from `profile.json`. Do not invent a server, a port, or a host.

## Invocation

- `/start-stack`
- `/start-stack <ticket id>`
- `/start-stack <ticket id> <preset>` (a name from `stacks.presets`)
- Add `-Setup` the first time on a machine: it runs each service's `setup` (install, restore) first.

## Workflow

1. Read `profile.stacks`. If `services` is empty (and no old `startCommand`), say there is no local stack and stop.
2. Run only the launcher. It claims the owner when a ticket id was given, then starts the preset's services in `dependsOn` order, waiting for each `ready` probe:

```powershell
./scripts/runtime/Start-TicketStack.ps1 -Ticket <ticket id> [-Preset <name>] [-Setup]
```

   An old profile with only `stacks.startCommand` still runs, as one service named `app`, with a
   migration warning; point the user at CUSTOMIZE.md (Stack recipes).

3. Report the command's exit status. If the ticket changes UI and the stack started, add one line: "Ask me for a browser smoke pass when you're ready to verify the UI change."
4. **If the user asked for that smoke pass:** after it finishes, **ask once** whether it passed.
   Stamp **only** after they answer:

   ```powershell
   ./scripts/ticket/Set-StackSmoke.ps1 -Ticket <ticket id> -Status passed|failed -Notes "<one line>" [-Preset <name>]
   ```

   - Yes / Tested → `-Status passed`
   - No / it failed → `-Status failed` only if they confirm that outcome
   - Decline to stamp → leave Never tested. Do **not** stamp from the agent's own judgment.

   `/review-changes` and `/complete-task` read this as optional extra confidence (`Get-StackSmoke.ps1`:
   Never tested / Tested / Untested latest changes). It never gates close. Do **not** stamp on stack
   start alone.
5. On failure, stop. Do not probe ports or restart a second copy unless the user passes `-Force` to `Start-TicketStack.ps1`.

## Guardrails

- Stack start is finished when the command's output prints or it fails. A smoke pass is a follow-up
  only if the user asks.
- After a user-requested smoke pass, ask whether it passed; `Set-StackSmoke.ps1` only after they answer.
- Do not start a second stack while another ticket owns it unless `-Force` was passed.
