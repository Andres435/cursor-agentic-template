# Workspace (Claude Code)

Agentic config lives in `{{folder}}/`. Cursor, Claude Code, and Codex each load it as a plugin.
This file is the Claude Code entry.

@{{folder}}/AGENTS.md
@{{folder}}/adapters/claude/model-usage.md

## Runtime

- Load the `{{plugin}}` plugin (`claude --plugin-dir {{folder}}`) so `/{{plugin}}:start-ticket` and
  the other workflow skills are available.
- `AGENTS.md` names tiers and verbs only. In Claude Code, tiers map to models in
  `{{folder}}/adapters/claude/model-usage.md` and verbs to tools in
  `{{folder}}/_shared/harness-verbs.md`. Pin engineering mode with `/{{plugin}}:engineering-mode`
  or the **{{plugin}}:Engineering mode** output style.
- Local stacks use `{{folder}}/scripts/*.ps1`.
