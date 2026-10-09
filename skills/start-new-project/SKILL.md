---
name: start-new-project
description: First run on a new product. Fills profile.json, the local-dev card, and the specialist stub. Does not start a ticket.
keywords: new project, profile, customize, interview
disable-model-invocation: true
icon: folder-plus
color: brand
---

# Start new project

Use this on a fresh clone of this template, before `/start-ticket`. Ask at most five questions per turn. Write nothing until that batch is answered. Do not invent defaults.

## Do not

- Copy another product's specialists, environment cards, or launch scripts into this repo.
- Invent a framework or add keys `profile.json` does not already have.
- Edit `slashCommands` or `epochRerateAfter`. Those are workflow contract, not product settings.
- Overwrite a profile whose `id` is no longer `customize-me` without asking first.
- Start a ticket, a stack, or a browser.

## Interview

1. **Product.** `id` (short slug) and `displayName`.
2. **Tracker.** `ticketSystem`: `none`, `github-issues`, or `ado`. `ticketPrefix` such as `TICKET-`, `#`, or `WI`.
3. **Repos.** One or more `{ name, path, layers }`. Path `.` means this repo. `dependencyOrder` in build order. `layout`: `monorepo` or `multi-repo`. `baseBranchDefault`.
4. **Worktrees.** `worktreeSupported` true or false. `defaultMode` stays `branch` unless the user asks for `worktree`.
5. **Stack.** Each local app is one `stacks.services` object. Ask per service, offering the matching recipe from [CUSTOMIZE.md](../../CUSTOMIZE.md#stack-recipes): `name`, `command` (long-running), `cwd` (relative to this repo), `setup` (install or restore, optional), `stop` (only when killing the process is not enough, such as `docker compose down`), `port` and `url`, `ready` (`{ "port": true }` or `{ "url": ... }`), `dependsOn`, and any `env` (use `${env:NAME}` for values, never a secret). With more than one service, ask which presets they want (for example `web` = just the front end). No local stack: leave `services` as `[]`.
6. **Specialist.** The stack in one paragraph for `agents/fullstack-specialist.md`. `specialists` lists that file's name without `.md`.
7. **Local dev.** Ports, URLs, prerequisites, and gotchas for `environments/local-dev.md`. No secrets.
8. **Optional.** `adrIndex` path or null. `integrations` names that match cards under `environments/`.

## Writes

After the user confirms the draft:

1. `profile.json` — replace only the fields above. Keep `slashCommands` and `epochRerateAfter`. Write `stacks` as `{ "default": "all", "presets": { "all": [] }, "services": [ ... ] }` (add the user's presets beside `all`); do not write `startCommand`. Do not put a product name, a secret, or a machine-specific absolute path in the profile.
2. `environments/local-dev.md` — replace the stub with the answers.
3. `agents/fullstack-specialist.md` — replace the stub with the stack paragraph. Keep `name` and `description` frontmatter.
4. `CUSTOMIZE.md` — check the three status boxes and fill **Choices**. Leave the field reference below that section in place.

Then tell the user the next command is `/doctor`, then `/start-ticket <id> feature`.
