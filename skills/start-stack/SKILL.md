---
name: start-stack
description: Local apps. Not a chat phase. Start the stack named in profile.json.
keywords: local stack, start apps, startCommand, active stack
disable-model-invocation: true
icon: terminal
color: green
---

# Start Stack

Start the local stack from `profile.json`. Do not invent a server, a port, or a host.

## Invocation

- `/start-stack`
- `/start-stack <ticket id>`

## Workflow

1. Read `profile.stacks.startCommand`.
2. If it is missing or `off`, say the stack is disabled and stop.
3. Claim the one owner file, then run only that command:

```powershell
./scripts/runtime/Set-ActiveStack.ps1 -Ticket <ticket id>
# then the profile start command, in the shell
```

4. Report the command's exit status. If the ticket changes UI and the stack started, add one line: "Ask me for a browser smoke pass when you're ready to verify the UI change."
5. **If the user asked for that smoke pass:** after it finishes, **ask once** whether it passed.
   Stamp **only** after they answer:

   ```powershell
   ./scripts/Set-StackSmoke.ps1 -Ticket <ticket id> -Status passed|failed -Notes "<one line>" [-Preset <name>]
   ```

   - Yes / Tested → `-Status passed`
   - No / it failed → `-Status failed` only if they confirm that outcome
   - Decline to stamp → leave Never tested. Do **not** stamp from the agent's own judgment.

   `/review-changes` and `/complete-task` read this as optional extra confidence (`Get-StackSmoke.ps1`:
   Never tested / Tested / Untested latest changes). It never gates close. Do **not** stamp on stack
   start alone.
6. On failure, stop. Do not probe ports or restart a second copy unless the user passes `-Force` to `Set-ActiveStack.ps1`.

## Guardrails

- Stack start is finished when the command's output prints or it fails. A smoke pass is a follow-up
  only if the user asks.
- After a user-requested smoke pass, ask whether it passed; `Set-StackSmoke.ps1` only after they answer.
- Do not start a second stack while another ticket owns it unless `-Force` was passed.
