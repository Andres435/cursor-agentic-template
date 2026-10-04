# Hook tests

Hook logic lives once in `hooks/core/` and names no IDE. Each IDE's hooks are thin
stdin/stdout adapters: Cursor in `adapters/cursor/hooks/` (wired by the root `hooks.json`),
Claude Code in `adapters/claude/hooks/` (wired by its `hooks.json`). The git hooks in
`hooks/git-hooks/` use the same core, so the plans hard stop and the push gate hold outside
any IDE.

These tests cover the core plus the Cursor adapters. The Claude adapters have their own suite,
`node adapters/claude/hooks/tests/claude-hooks.test.js`, which also fails if a Cursor hook has
no Claude counterpart. Run both after changing hook logic.

Requires only Node.js (no framework). Run from the workspace root, for example:

```bash
node hooks/tests/commit-guard.test.js
node hooks/tests/context-usage.test.js
```

| Test file | Under test | What it checks |
|---|---|---|
| `closeout-guard.test.js` | `core/closeout-guard.js` via the Cursor adapter | Deny closeout dumps, allow other files, degrade on bad JSON |
| `session-context.test.js` | `core/session-context.js` via the Cursor adapter | Packet shape, env keys, graceful degrade without PowerShell |
| `git-push-agentic-flow.test.js` | `core/push-gate.js`, both adapters | Gate only pushes of the workflow clone; `echo "git push"` is not a push |
| `ticket-command-nudge.test.js` | `core/ticket-nudge.js` via the Cursor adapter | Fire only on a leading slash command; engineering-mode names the playbook |
| `commit-guard.test.js` | `core/commit-guard.js`, `git-hooks/pre-commit` | Deny user-local plans/ files; ask for a WI id only in product repos |
| `context-usage.test.js` | `core/context-usage.js`, Claude Stop hook | Measured context from a transcript; per-session record |

All exit 0 on success, 1 on failure. Safe to run without TmoPro or PowerShell installed;
`session-context.test.js` stubs the Resolve-TicketRoot path (script not found → graceful degrade).
