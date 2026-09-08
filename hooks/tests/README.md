# Hook smoke tests

Requires only Node.js (no framework). Run from the workspace root:

```bash
node hooks/tests/closeout-guard.test.js
node hooks/tests/session-context.test.js
```

| Test file | Hook under test | What it checks |
|---|---|---|
| `closeout-guard.test.js` | `closeout-read-guard.js` | Deny closeout dumps, allow other files, degrade on bad JSON |
| `session-context.test.js` | `session-context.js` | Packet shape, env keys, graceful degrade without PowerShell |

Both exit 0 on success, 1 on failure. Safe to run without a configured project or PowerShell;
`session-context.test.js` stubs the Resolve-TicketRoot path (script not found → graceful degrade).
