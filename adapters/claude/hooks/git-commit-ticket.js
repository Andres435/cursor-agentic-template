#!/usr/bin/env node
"use strict";

// Claude Code PreToolUse hook (matcher: Bash) for git add/commit. Logic lives in
// ../../../hooks/core/commit-guard.js; this file only speaks Claude's contract:
// tool_input.command on stdin, hookSpecificOutput.permissionDecision on stdout.

const { decide } = require("../../../hooks/core/commit-guard.js");

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const toolInput = input.tool_input || {};
    const command = String(toolInput.command || "");
    const cwd = String(input.cwd || toolInput.cwd || process.cwd());
    const d = decide({ command, cwd });
    if (d.action !== "allow") {
      process.stdout.write(
        JSON.stringify({
          hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: d.action,
            permissionDecisionReason: d.reason,
          },
        })
      );
    }
    process.exit(0);
  } catch (_err) {
    process.exit(0);
  }
});
