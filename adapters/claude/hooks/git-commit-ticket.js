#!/usr/bin/env node
"use strict";

// Claude Code PreToolUse bridge for git add/commit. Logic lives in
// ../../../hooks/core/commit-guard.js; this file only speaks Claude's contract:
// tool_input.command in, hookSpecificOutput.permissionDecision out. hooks.json runs it
// through git-guard.js (one node process for both git hooks); run directly it reads stdin.

const { decide } = require("../../../hooks/core/commit-guard.js");
const { writeHookError } = require("../../../hooks/core/hook-log.js");

/** The PreToolUse output for one tool call, or null to stay silent. */
function handle(input) {
  try {
    const toolInput = (input && input.tool_input) || {};
    const command = String(toolInput.command || "");
    const cwd = String((input && input.cwd) || toolInput.cwd || process.cwd());
    const d = decide({ command, cwd });
    if (d.action === "allow") return null;
    return {
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: d.action,
        permissionDecisionReason: d.reason,
      },
    };
  } catch (err) {
    // Logged for /doctor; the git pre-commit hook is the backstop for staged plans/ files.
    writeHookError("claude:git-commit-ticket", err);
    return null;
  }
}

module.exports = { handle };

if (require.main === module) {
  let raw = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => {
    raw += chunk;
  });
  process.stdin.on("end", () => {
    let input = {};
    try {
      input = JSON.parse(raw || "{}");
    } catch (err) {
      writeHookError("claude:git-commit-ticket", err);
    }
    const out = handle(input);
    if (out) process.stdout.write(JSON.stringify(out));
    process.exit(0);
  });
}
