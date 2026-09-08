# TEMPLATE.md — Maintainer map

This file is for maintainers of `cursor-agentic-template`. It defines what is **core** (stable,
copied to all projects) vs **overlay** (per-project, never overwritten by upstream).

---

## Core — do not break across versions

| Path | Notes |
|---|---|
| `skills/workflow/` | Ticket lifecycle skills (start-ticket, implement, complete-task, etc.) |
| `scripts/ticket/` | Assert-TicketArtifacts, Resolve-TicketRoot, Update-TicketLedger, Search-CloseoutMemory |
| `scripts/machine/` | Initialize-WorkflowMachine |
| `hooks/` + `hooks.json` | sessionStart, closeout-read-guard, git-commit-ticket, preCompact, nudge |
| `hooks/tests/` | Smoke tests for hooks — run before releasing a new core version |
| `_shared/ticket-artifacts.md` | Phase gate contract |
| `_shared/ticket-plan-output.md` | Plan and closeout structure |
| `_shared/severity-and-output.md` | Token-class law + finding format |
| `_shared/subagent-functions.md` | Subagent function contracts |
| `commands/` shims | start-ticket, implement, complete-task, prep-pr, review-changes, start-stack |
| `rules/model-usage.mdc` | Always-on model rails |
| `adapters/claude/model-usage.md` | Claude Code adapter |
| `plans/ticket-ledger.md` (header only) | Ledger format — rows are project data |

## Overlay — per-project, safe to customize

| Path | Notes |
|---|---|
| `profile.json` | Project config — the only required customization |
| `CUSTOMIZE.md` | Onboarding checklist |
| `agents/` | Project specialists |
| `environments/` | Env cards and local-dev stubs |
| `skills/domain/` | Project-specific domain skills |
| `scripts/runtime/` | Stack launcher (reads `profile.stacks.startCommand`) |
| `rules/workspace-context.mdc` | Project workspace disambiguation |
| `USER-MANUAL.md` | Add project-specific notes (base text is core) |
| `MACHINE-SETUP.md` | Add project-specific machine setup (base text is core) |
| `mcp.json` | MCP server config (project-specific secrets/endpoints) |

## Versioning

Tag releases as `core-vX.Y.Z`. Projects cherry-pick or copy core files from a tag.
Do not use `git merge` template-into-project — it will overwrite overlay files.

## Adding to core

Before adding a file to core:
1. Is it zero TMO/project-specific strings? Run the TMO string check.
2. Does it have a test (hooks) or a budget check (doc budget)?
3. Does it follow the progressive disclosure pattern (≤40-line command shim + skill references)?
