#!/usr/bin/env node
"use strict";

// Claude Code PreToolUse bridge for git push. Logic lives in
// ../../../hooks/core/push-gate.js; this file speaks Claude's contract. hooks.json runs it
// through git-guard.js (one node process for both git hooks); run directly it reads stdin.

const { gate, denyMessage, failsClosed, crashMessage } = require("../../../hooks/core/push-gate.js");
const { writeHookError } = require("../../../hooks/core/hook-log.js");

function deny(reason) {
  return {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: reason,
    },
  };
}

/** The PreToolUse output for one tool call, or null to stay silent. */
function handle(input) {
  let command = "";
  let cwd = process.cwd();
  try {
    command = String(((input && input.tool_input) || {}).command || "");
    cwd = String((input && input.cwd) || process.cwd());
    const failed = gate(command, cwd);
    return failed ? deny(denyMessage(failed.output, failed)) : null;
  } catch (err) {
    writeHookError("claude:git-push-agentic-flow", err);
    // An unchecked push of the workflow repo is what this gate exists to stop.
    return failsClosed(command, cwd) ? deny(crashMessage(err)) : null;
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
      writeHookError("claude:git-push-agentic-flow", err);
    }
    const out = handle(input);
    if (out) process.stdout.write(JSON.stringify(out));
    process.exit(0);
  });
}
