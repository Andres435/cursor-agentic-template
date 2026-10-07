#!/usr/bin/env node
"use strict";

// Cursor beforeShellExecution hook for git add/commit. Logic lives in ../../../hooks/core/commit-guard.js;
// this file only speaks Cursor's contract ({ permission, user_message, agent_message }).

const { decide } = require("../../../hooks/core/commit-guard.js");
const { writeHookError } = require("../../../hooks/core/hook-log.js");

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const command = String(input.command || input.command_line || input.cmd || "");
    const roots = Array.isArray(input.workspace_roots) ? input.workspace_roots : [];
    const cwd = String(input.cwd || input.working_directory || roots[0] || process.cwd());
    const d = decide({ command, cwd });
    if (d.action === "allow") {
      process.stdout.write(JSON.stringify({ permission: "allow" }));
      return;
    }
    const agent =
      d.action === "deny"
        ? d.reason
        : "Hook blocked a git commit without a work-item id. Ask the user to include " +
          d.suggested +
          " in the message (do not commit until they confirm).";
    process.stdout.write(JSON.stringify({ permission: d.action, user_message: d.reason, agent_message: agent }));
  } catch (err) {
    // Logged for /doctor; the git pre-commit hook is the backstop for staged plans/ files.
    writeHookError("cursor:git-commit-ticket", err);
    process.stdout.write(JSON.stringify({ permission: "allow" }));
  }
});
