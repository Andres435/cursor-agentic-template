# User Manual

Day-to-day ticket workflow for humans. Agents: see [AGENTS.md](AGENTS.md).

**First clone:** run `/start-new-project`. It fills [profile.json](profile.json) and
[CUSTOMIZE.md](CUSTOMIZE.md). Then `/onboard` for the machine script. After that, slash commands
run from the profile — they do not re-ask for repos or start commands.

## Three-chat lifecycle (branch mode — default)

Branch mode is three chats.

| Chat | What happens |
|---|---|
| **Chat 1 `/start-ticket`** | Plan → approve → **build in the same chat** |
| **Chat 2 `/review-changes`** | Staged review; stamps `reviewReady` |
| **Chat 3 `/complete-task`** | Verify → retrospective → ledger row → PR package |

`/prep-pr` runs after you approve the package. `/implement` is only for worktree mode or a
start-ticket chat that ran out of context.

Worktree mode (`--worktree`) is opt-in and only if `profile.worktreeSupported` is true.

## Slash commands

| Command | When |
|---|---|
| `/start-new-project` | Interview that fills profile, checklist, env card, and specialist |
| `/onboard` | Machine setup after the profile exists |
| `/engineering-mode` | Pin, then type only the ticket command |
| `/doctor` | Health check (profile, hooks, gates) |
| `/start-ticket TICKET-42 feature` | New work (feature, bug, spike, refactor) |
| `/start-ticket TICKET-42 bug --worktree` | Isolated worktree (optional) |
| `/implement TICKET-42` | Resume / worktree build |
| `/review-changes` | Staged review before PR |
| `/complete-task` | Close a finished ticket (new chat) |
| `/prep-pr` | Commit / push / PR / tracker write-back |
| `/start-stack TICKET-42` | Start `profile.stacks.startCommand` |
| `/address-pr-comments TICKET-42` | Address reviewer comments |
| `/peer-review <id>` | Draft comments; post only what you approve |
| `/swap-stack <id>` | Give the stack to another ticket |
| `/stop-stack` | Release the stack owner |

## Model selection

Tiers are `fast`, `standard`, `deep`, and `frontier`. The map for this IDE is under `adapters/`.
`/engineering-mode` routes each step to its tier. A local login file, gitignored, is optional for a browser pass — do not commit it.


## Done table

| Phase | Artifact | Script gate |
|---|---|---|
| Start | `plans/<ticket>-manifest.json`, `plans/<ticket>-<type>-plan.md` (Plan Digest + Engineering Decisions) | `Assert-TicketArtifacts -Phase start` |
| Review | `reviewReady` + `ctxPct.review` on the manifest | `Set-ReviewReady` / `Set-TicketCtxPct` |
| Close | Ledger row (`CtxS%` / `CtxR%` / `Ctx%`) | `Assert-TicketArtifacts -Phase close` |

## Customize this manual

Add project-specific notes below (stack-specific commands, auth steps, known gotchas).
