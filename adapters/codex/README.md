# Codex adapter

Loads the shared workflow in **Codex**. Routing, skills, and agents stay in the repo root. This
folder maps tiers to Codex `spawn_agent` models ([model-usage.md](model-usage.md), `deepLane: inline`).
The selected model is the deep tier and stays inline. Fast and standard lanes pass `model` from
that file. Codex has no context hook, so `report-context` stays blank.

Cursor chats on a GPT picker use [../gpt/model-usage.md](../gpt/model-usage.md), not this file.

## Enable

Codex discovers skills one level under `skills/<name>/SKILL.md`. The manifest is
[.codex-plugin/plugin.json](../../.codex-plugin/plugin.json) and points `skills` at `./skills/`.

```text
codex plugin marketplace add <path to this folder>
```

Then install the `agentic` plugin from that marketplace and restart Codex. A Codex session reads
[model-usage.md](model-usage.md) because `AGENTS.md` points at it; there is no `@` include.

## What stays in the repo root

| Shared | Codex |
|---|---|
| `_shared/model-routing.md` (tiers only) | [model-usage.md](model-usage.md) |
| `_shared/harness-verbs.md` (verbs) | Codex column of that map |
| `hooks/core/` | no Codex hook adapter yet; the git hooks in `hooks/git-hooks/` still apply |
| `skills/<name>/SKILL.md` | same files, discovered one level deep |
| `.claude-plugin/plugin.json` | `.codex-plugin/plugin.json` |

`/doctor --lanes` from a Codex parent records which `spawn_agent` model each tier honored. Copy those
ids into the tier table. Do not guess them.
