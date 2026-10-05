# `_shared/` — Cross-phase contracts

Contracts that more than one command reads. Phase-only detail lives in a skill's `references/`.
Find a doc through [../INDEX.md](../INDEX.md); terms are defined in [glossary.md](glossary.md).

## One owner per rule

A rule lives in one doc; everywhere else links to it. Two restatements are allowed:

- **A guardrail at the action site:** the "no commit, push, PR, or tracker write without approval"
  line in each command that could do one of those things (implement, complete-task, prep-pr,
  address-pr-comments, peer-review, ticket-context-load, start-ticket).
- **Prompt text sent to a subagent:** a subagent does not see the parent chat, so its packet repeats
  what it must not do.

Anything else that repeats a rule (chat counts, artifact lists, search recipes) becomes a link. The
chat-count owner is [USER-MANUAL](../USER-MANUAL.md); the file list per phase is
[ticket-artifacts](ticket-artifacts.md).

## Tips

- Prefer the **slice** named in the command or skill over pasting a whole file into chat.
- Reload results from the ticket manifest (the stamp scripts write them there) instead of
  re-fetching tracker or analysis JSON every turn; no side files under `plans/`.
