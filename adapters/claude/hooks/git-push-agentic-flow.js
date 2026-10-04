#!/usr/bin/env node
"use strict";

// Claude Code PreToolUse hook (matcher: Bash) for git push. Logic lives in
// ../../../hooks/core/push-gate.js; this file speaks Claude's contract.

const { gate, denyMessage } = require("../../../hooks/core/push-gate.js");

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const command = String((input.tool_input || {}).command || "");
    const failed = gate(command, String(input.cwd || process.cwd()));
    if (failed) {
      process.stdout.write(
        JSON.stringify({
          hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: denyMessage(failed.output),
          },
        })
      );
    }
    process.exit(0);
  } catch {
    process.exit(0);
  }
});
