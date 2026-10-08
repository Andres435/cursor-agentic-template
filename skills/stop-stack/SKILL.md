---
name: stop-stack
description: Local apps. Not a chat phase. Release the stack owner.
keywords: stop stack, active stack
disable-model-invocation: true
icon: zap
color: red
---

# Stop Stack

Stop the services `Start-TicketStack.ps1` recorded, then release the owner. Do not invent a second stop command.

```powershell
./scripts/runtime/Stop-TicketStack.ps1
```

Report the exit status. Stopping does not erase a recorded smoke stamp; `Get-StackSmoke.ps1` marks it
Untested latest changes if the work changes later.
