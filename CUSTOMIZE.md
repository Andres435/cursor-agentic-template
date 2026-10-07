# Customize this workflow for your project

Run `/start-new-project`. It asks five short batches and fills `profile.json`, the status boxes
below, and `environments/local-dev.md`. Hand-editing this file still works.

Sections marked `(required)` must be done before running `/start-ticket`.

**Rule:** these blanks are setup and context. After they are filled, `/start-ticket` and the rest of
the workflow run **automatically** from `profile.json` — they will not re-interview you for repos,
stack, or specialists.

## Status

`/start-new-project` checks these and records the answers under Choices.

- [ ] `profile.json`
- [ ] `environments/local-dev.md`
- [ ] Specialists recorded in `profile.json`

## Choices

Filled by `/start-new-project`. Leave this blank until that command runs.

- **Product:**
- **Tracker:**
- **Layout:**
- **Stack:**
- **Overlay:**

---

## 1. Edit `profile.json` (required)

Open `profile.json` and fill in your project's values:

| Field | What to set |
|---|---|
| `id` | Short slug for your project (e.g. `my-app`) |
| `displayName` | Human-readable project name |
| `ticketSystem` | `none` \| `github-issues` \| `ado` |
| `ticketPrefix` | Ticket ID prefix (e.g. `TICKET-`, `#`, `WI`) |
| `repos[].name` | Your repo name(s) |
| `repos[].path` | Path relative to the `.cursor` folder (`.` for same repo) |
| `specialists` | Match names to agent files in `agents/` |
| `stacks.startCommand` | Command to start your dev server (e.g. `npm run dev`) |
| `uiGlobs` | File types that count as UI (default `*.js`, `*.jsx`, `*.ts`, `*.tsx`, `*.css`, `*.scss`, `*.html`). Close needs a user-confirmed Drive only when a `frontend` repo's change touches one; add your templates (e.g. `*.vue`, `*.cshtml`) |

**Multi-repo:** add one object per repo to `repos[]` in dependency order (e.g. `["shared", "api", "web"]`).

---

## 2. Fill `environments/local-dev.md` (required)

Replace the stub with your actual:
- Ports and URLs
- Prerequisites and install steps
- Common gotchas (missing env vars, certs, auth tokens)

---

## 3. Customize the fullstack specialist (required)

Edit `agents/fullstack-specialist.md` with your actual tech stack and key conventions. Add more
specialist files if needed (e.g. `backend-specialist.md`, `frontend-specialist.md`) and list them
in `profile.json` → `specialists`.

---

## 4. Set up ticket system (if not `none`)

### GitHub Issues

Add `github-ticket-workflow.md` under `skills/start-ticket/references/` with your intake steps.
See `skills/start-ticket/references/ticket-intake-generic.md` for the pattern.

### Azure DevOps (ADO)

Add `ado-ticket-workflow.md` under `skills/start-ticket/references/` (fetch, required fields, the State
moves you allow) and, if you write fields back, `ado-field-mapping.md`. Use
`ticket-intake-generic.md` as the pattern. Add an `ado` server to `mcp.json` (token in a user
environment variable). Then set `ticketSystem: "ado"` and `ticketPrefix: "WI"` in `profile.json`.

---

## 5. Bootstrap the machine (one-time per machine)

```powershell
scripts/machine/Initialize-WorkflowMachine.ps1
```

This reports missing tools, writes the Claude Code overlay, and installs the git hooks. Phases for
Cursor extensions, user settings, and a cockpit workspace run only when your overlay adds their
scripts to `scripts/machine/`. Details: [MACHINE-SETUP.md](MACHINE-SETUP.md).

---

## 6. Start your first ticket

```
/start-ticket TICKET-1 feature
```

Or with GitHub Issues:
```
/start-ticket #1 feature
```

---

## What NOT to edit

These are **core** files — leave them alone unless you are upgrading the workflow:

- `skills/` (add your own skills beside them; add intake references under
  `skills/start-ticket/references/`)
- `hooks/`, `hooks.json`, `adapters/`, `output-styles/`
- `scripts/ticket/`, `scripts/machine/`
- `_shared/`

---

## Getting upstream updates

```bash
# From this folder, with the template added as the upstream remote
git fetch upstream
git checkout upstream/main -- skills/ _shared/ scripts/ticket/ scripts/machine/ hooks/ adapters/ output-styles/
```

That overwrites core skill folders, so re-add any project skill or intake reference you keep under
`skills/`, then run `scripts/ticket/Assert-AgenticFlow.ps1`. Your overlay (`profile.json`,
`environments/`, `agents/`, `mcp.json`) is not touched.
