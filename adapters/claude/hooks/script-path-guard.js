#!/usr/bin/env node
"use strict";

// Claude Code PreToolUse hook (matcher: Write|Edit|MultiEdit; shell calls arrive through git-guard.js, one process). The decision is
// ../../../hooks/core/script-path-guard.js; this file speaks Claude's contract.

const { decideWrite, decideRun } = require("../../../hooks/core/script-path-guard.js");
const { writeHookError } = require("../../../hooks/core/hook-log.js");

function handle(input) {
  const tool = String((input && input.tool_name) || "");
  const ti = (input && input.tool_input) || {};
  const answer = /^(?:Write|Edit|MultiEdit)$/.test(tool) ? decideWrite(ti.file_path) : decideRun(ti.command);
  if (!answer) return null;
  return {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: answer.reason,
    },
  };
}

module.exports = { handle };

if (require.main === module) {
  let raw = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => {
    raw += chunk;
  });
  process.stdin.on("end", () => {
    try {
      const out = handle(JSON.parse(raw || "{}"));
      if (out) process.stdout.write(JSON.stringify(out));
    } catch (err) {
      writeHookError("script-path-guard", err);
    }
    process.exit(0);
  });
}
