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

4. Report the command's exit status. If the ticket changes UI and the stack started, add one line: ask before any browser pass.
5. On failure, stop. Do not probe ports or restart a second copy unless the user passes `-Force` to `Set-ActiveStack.ps1`.
