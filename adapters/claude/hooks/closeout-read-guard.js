#!/usr/bin/env node
"use strict";

// Claude Code PreToolUse hook (matcher: Read). The path filter is
// ../../../hooks/core/closeout-guard.js; this file speaks Claude's contract:
// tool_input.file_path on stdin, hookSpecificOutput.permissionDecision on stdout.

const { isCloseoutDump, DENY_MSG } = require("../../../hooks/core/closeout-guard.js");

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const toolInput = input.tool_input || {};
    const filePath = String(toolInput.file_path || toolInput.path || toolInput.notebook_path || "");
    if (!isCloseoutDump(filePath)) {
      process.exit(0);
      return;
    }
    process.stdout.write(
      JSON.stringify({
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: DENY_MSG,
        },
      })
    );
  } catch {
    process.exit(0);
  }
});
