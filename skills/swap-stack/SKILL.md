---
name: swap-stack
description: Local apps. Not a chat phase. Give the one stack to another ticket.
keywords: swap stack, active stack
disable-model-invocation: true
icon: git-branch
color: cyan
---

# Swap Stack

1. Read `profile.stacks.startCommand`. If it is missing or `off`, say the stack is disabled and stop.
2. Release the current owner, claim the target ticket, then run the same start command:

```powershell
./scripts/runtime/Set-ActiveStack.ps1 -Ticket <ticket id> -Force
```

3. Report the exit status. Do not start a second stack for a different ticket without `-Force`.
