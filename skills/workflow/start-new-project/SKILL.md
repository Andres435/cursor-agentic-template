---
name: start-new-project
description: Interview for a brand-new product and fill profile.json, CUSTOMIZE.md, and environments/local-dev.md. Does not invent a framework or start the stack.
keywords: new project, profile, customize, local-dev, template
disable-model-invocation: true
---

# Start New Project

Run this once on a fresh `cursor-agentic-template` clone, before `/start-ticket`. It replaces hand-editing [../../../CUSTOMIZE.md](../../../CUSTOMIZE.md).

## Do not

- Invent a framework, pick Next vs Vite vs .NET, or copy TMO presets, IIS, Caddy, or Miniter launchers.
- Run the start command or `/start-stack`.
- Create a profile, branch, or folder named greenfield. The profile `id` is the product id from the interview.
- Add keys `profile.json` does not already have.

## Interview

At most five questions per turn. Write nothing until that batch is answered. Do not invent defaults.

1. **Product.** Display name, profile `id` (short slug), one-line purpose.
2. **Tracker.** `none` (local ids), `github-issues`, or `ado`. Prefix (`TICKET-`, `#`, `WI`).
3. **Layout.** One repo (`layout` `monorepo`, `repos[0].path` `.`) or sibling clones (`layout` `multi-repo`, one `repos[]` entry per clone, `dependencyOrder` in build order).
4. **Stack.** On or off. If on, the real start command (`npm run dev`, `dotnet watch`, Docker, or a script path). No TMO preset names.
5. **Overlay.** Specialists to keep (default `fullstack` if they have no other). `adrIndex` path or null. `worktreeSupported` true or false. `baseBranchDefault` (`main` unless they name another).

If `profile.json` `id` is no longer `customize-me`, stop and ask before overwriting.

## Writes

After the user confirms the draft, overwrite only these three files.

`profile.json` — same keys as the template stub:

- `id`, `displayName`, `ticketSystem`, `ticketPrefix`, `layout`, `defaultMode` (`branch`), `worktreeSupported`, `baseBranchDefault`
- `repos`, `dependencyOrder`, `specialists`, `adrIndex`, `integrations` (leave `[]` unless they named one)
- `stacks.default` stays `dev`. `stacks.startCommand` is their command, or `""` when the stack is off.

`environments/local-dev.md` — replace the stub. Keep the headings Start command, Ports, Prerequisites, Common gotchas, Verify. Put the one-line purpose and the stack on/off choice in Start command. No secrets. No TMO cards.

`CUSTOMIZE.md` — check the status boxes at the top and write the chosen values under **Choices**. Leave the field reference below that section in place.

## Stop

Print the profile `id`, the start command, and this line: run `/doctor`.

If `stacks.startCommand` is not a file path, say that `/doctor` check 4 looks for a file and will fail on a shell command such as `npm run dev`. `/start-stack` still execs that command directly. Do not add a launcher script unless the user asks.
