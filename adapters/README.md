# `adapters/` — Per-runtime overlays

The repo root names verbs and tiers. Each adapter's `model-usage.md` maps tiers, subagent roles,
and `deepLane`. Verbs: [../_shared/harness-verbs.md](../_shared/harness-verbs.md).

| Adapter | Runtime | `deepLane` |
|---|---|---|
| [cursor/](cursor/README.md) | Cursor | dispatch |
| [claude/](claude/README.md) | Claude Code | dispatch |
| [gpt/](gpt/model-usage.md) | Cursor chat on a GPT picker | inline |
| [codex/](codex/README.md) | Codex | inline |

Hook logic lives once in [`../hooks/core/`](../hooks/core/). `cursor/hooks/` and `claude/hooks/` are thin adapters over it.
