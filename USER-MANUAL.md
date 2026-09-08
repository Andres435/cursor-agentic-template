# User Manual

Day-to-day ticket workflow for humans. Agents: see [AGENTS.md](AGENTS.md).

## Two-chat lifecycle (branch mode — default)

| Chat | What happens |
|---|---|
| **Chat 1 `/start-ticket`** | Plan → approve → implement → push (all in one chat) |
| **Chat 2 `/complete-task`** | Verify → retrospective → ledger row → PR prep |

Worktree mode (opt-in with `--worktree`): three chats — plan, implement, complete. Default is branch mode.

## Slash commands

| Command | When |
|---|---|
| `/start-ticket TICKET-42 feature` | New work item (feature, bug, spike, refactor) |
| `/start-ticket TICKET-42 bug --worktree` | New ticket in isolated worktree (optional) |
| `/complete-task` | Close a finished ticket (new chat) |
| `/prep-pr` | Finalize PR and write-back to ticket system |
| `/review-changes` | Code review before PR |
| `/review-changes TICKET-42` | Pre-merge review of a branch |
| `/start-stack TICKET-42` | Start the local dev stack |
| `/address-pr-comments TICKET-42 PR_NUMBER` | Address reviewer comments |

## Model selection

- **Plan step** → switch to Grok 4.5 (or Opus in Claude Code) before planning.
- **Task steps** → Auto / Composer; honor `[low]|[med]|[high]` tags in the Work Plan.
- **New chat** (`/complete-task`) → Auto is fine; no planning needed.

## Done table

| Phase | Artifact | Script gate |
|---|---|---|
| Start | `plans/<ticket>-manifest.json`, `plans/<ticket>-<type>-plan.md` | `Assert-TicketArtifacts -Phase start` |
| Implement | Changes committed + pushed | (per plan steps) |
| Close | Ledger row, optional closeout | `Assert-TicketArtifacts -Phase close` |

## Customize this manual

Add project-specific notes below (stack-specific commands, auth steps, known gotchas).
