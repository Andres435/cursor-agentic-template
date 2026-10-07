# `commands/` — menu notes

Slash workflows are skills: `skills/<name>/SKILL.md`, with `playbooks/` and `references/` beside that file.
This folder no longer holds slash entries. A command file whose name matches a skill shows up twice.

| Goal | Command |
|---|---|
| Fill profile, env card, and specialist on a new product | `/start-new-project` |
| Pin for ad-hoc work or a long chat. Do not type it in the same message as a ticket command | `/engineering-mode` |
| Start a ticket | `/start-ticket <id> bug\|feature\|spike` |
| Build in a fresh chat | `/implement <id>` |
| Start, swap, or stop the local stack | `/start-stack`, `/swap-stack`, `/stop-stack` |
| Review ticket files; stage the clean ones | `/review-changes` |
| Closeout package | `/complete-task` |
| Commit, push, and open the PR after approval | `/prep-pr` |
| Triage review feedback | `/address-pr-comments` |
| Review a coworker's PR | `/peer-review <id>` |
| Health check | `/doctor` |
| Machine setup | `/onboard` |

Branch mode is three chats: `/start-ticket` (plan and build), `/review-changes`, `/complete-task`.
`/implement` is only for a fresh chat. Plan shapes (`bug-fix`, `feature-plan`, `tech-spike`, `document-spike`) are not slash commands.

Icons: run `scripts/Install-UserCursorCommands.ps1`, then reload. Cursor paints badges on user skills, not on plugin copies.
