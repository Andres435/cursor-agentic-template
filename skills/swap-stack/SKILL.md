---
name: swap-stack
description: Local apps. Not a chat phase. Give the one stack to another ticket.
keywords: swap stack, active stack, preset
disable-model-invocation: true
icon: git-branch
color: cyan
---

# Swap Stack

1. Read `profile.stacks.services`. If it is empty, say there is no local stack and stop.
2. Run the swap launcher. It stops the running stack (`Stop-TicketStack.ps1 -Force`), claims the target
   ticket (`Set-ActiveStack.ps1 -Force`), then starts it (`Start-TicketStack.ps1`) with the same preset:

```powershell
./scripts/runtime/Swap-TicketStack.ps1 -Ticket <ticket id> [-Preset <name>] [-Setup]
```

3. Report the exit status. If the stop fails, nothing is claimed or started.
4. A smoke pass on the new stack follows [start-stack](../start-stack/SKILL.md) step 5: ask once
   whether it passed, then `Set-StackSmoke.ps1` only after they answer. Never stamp on swap alone.
