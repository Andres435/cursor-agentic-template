# TEMPLATE.md — Maintainer map

What is **core** (stable across products) vs **overlay** (per project).

## Core

| Path | Notes |
|---|---|
| `skills/<name>/SKILL.md` | One folder per skill. `playbooks/` and `references/` sit beside it |
| `skills/start-new-project/` | Fills `profile.json` for a new product |
| `scripts/ticket/` | Artifact gate, epoch, ledger, review stamp, measured Ctx% |
| `scripts/machine/` | Machine init and user-level slash links |
| `scripts/runtime/Set-ActiveStack.ps1` | One stack owner file |
| `hooks/core/` + `hooks.json` | Shared hook logic; IDE bridges live under `adapters/` |
| `hooks/tests/` | Hook smoke tests |
| `_shared/ticket-artifacts.md` | Phase gate contract |
| `_shared/ticket-plan-output.md` | Plan and closeout structure |
| `_shared/engineering-decisions.md` | Plan decision gate |
| `_shared/model-routing.md` | Tier contract |
| `_shared/harness-verbs.md` | IDE-neutral verbs |
| `_shared/severity-and-output.md` | Token-class law |
| `commands/_README.md` | Menu notes. No slash shim that duplicates a skill |
| `.cursor-plugin/`, `.claude-plugin/`, `.codex-plugin/` | Same skills, three hosts |

## Overlay

| Path | Notes |
|---|---|
| `profile.json` | Product config. `/start-new-project` fills it. Do not drop `slashCommands` |
| `CUSTOMIZE.md` | Checklist |
| `agents/` | Specialists |
| `environments/` | Env cards |
| `scripts/runtime/` besides the stack owner | The profile start command |
| `USER-MANUAL.md` | Project notes below the core section |
| `mcp.json` | Project MCP servers |

## Versioning

Tag releases as `core-vX.Y.Z`. Projects copy core files from a tag.
Do not `git merge` a product repo into this template.

## Adding to core

1. Zero product strings (`TmoPro`, `IIS Express`, `Custom.StoryPointsActual`). The template-vanilla check scans `skills/` and `_shared/`.
2. A hook test or a doc-budget check.
3. `skills/<name>/SKILL.md` with `icon` and `color`. Playbooks live in `playbooks/`, not a repo-root folder and not `PLAYBOOK.md` beside `SKILL.md`.
