# Machine setup

One-time setup for a laptop that will run this workflow. No Visual Studio, IIS, or Azure CLI
unless your project overlay adds them.

## 1. Folder layout

Place this folder at `<app>/.cursor` (monorepo) or `source/repos/.cursor` (multi-repo siblings).

```
my-app/
  .cursor/          ← this repo
  package.json
```

or

```
source/repos/
  .cursor/          ← this repo
  app/
```

Repos and paths are defined in `profile.json`. Do not hardcode product names.

## 2. Prerequisites

- [Cursor](https://cursor.com)
- Git
- Node.js ≥ 20 (for hooks and typical `npm run dev`)
- PowerShell 7 (`pwsh`) if you use the ticket scripts on macOS/Linux

## 3. Bootstrap

```powershell
.\.cursor\scripts\machine\Initialize-WorkflowMachine.ps1
```

Installs recommended Cursor extensions and applies `user/settings.recommended.json` plus
command junctions so slash commands appear in every window.

## 4. First ticket

1. Edit `profile.json` and [CUSTOMIZE.md](CUSTOMIZE.md).
2. Fill `environments/local-dev.md`.
3. `/start-ticket TICKET-1 feature`

## 5. Optional

- GitHub CLI (`gh`) if `ticketSystem` is `github-issues`.
- MCP servers: copy examples from `mcp.json` and fill secrets locally — do not commit tokens.
