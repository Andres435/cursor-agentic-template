# Customize this workflow for your project

This is the **only file you need to edit to get started**. Work through the checklist top to bottom.
Sections marked `(required)` must be done before running `/start-ticket`.

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

Add `skills/workflow/start-ticket/references/github-ticket-workflow.md` with your intake steps.
See `skills/workflow/start-ticket/references/ticket-intake-generic.md` for the pattern.

### Azure DevOps (ADO)

Copy ADO reference files from the TMO workspace:
- `skills/workflow/start-ticket/references/ado-ticket-workflow.md`
- `skills/workflow/start-ticket/references/ado-field-mapping.md`
- `_shared/ado-ticket-workflow.md`

Then set `ticketSystem: "ado"` and `ticketPrefix: "WI"` in `profile.json`.

---

## 5. Bootstrap the machine (one-time per machine)

```powershell
.\.cursor\scripts\machine\Initialize-WorkflowMachine.ps1
```

This installs recommended Cursor extensions and applies the recommended settings.

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

- `skills/workflow/` (except adding intake references)
- `hooks/`, `hooks.json`
- `scripts/ticket/`
- `_shared/ticket-artifacts.md`, `_shared/severity-and-output.md`, `_shared/ticket-plan-output.md`

To upgrade core later: cherry-pick or copy those files from the template repo.

---

## Getting upstream updates

Core files (workflow skills, ticket scripts, hooks) can be updated from the template repo:

```bash
# From your project's .cursor folder
git fetch upstream
git checkout upstream/main -- skills/workflow/ scripts/ticket/ hooks/ _shared/ticket-artifacts.md
```

Your overlay files (`profile.json`, `environments/`, `agents/`, `skills/domain/`) are never touched
by upstream updates.
