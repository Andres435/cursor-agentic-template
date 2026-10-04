#!/usr/bin/env node
"use strict";

// Cursor beforeShellExecution hook for git push. Logic lives in ../../../hooks/core/push-gate.js;
// this file speaks Cursor's contract ({ permission, user_message, agent_message }).

const { gate, denyMessage } = require("../../../hooks/core/push-gate.js");

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
    const failed = gate(command, cwd);
    if (!failed) {
      process.stdout.write(JSON.stringify({ permission: "allow" }));
      return;
    }
    const msg = denyMessage(failed.output);
    process.stdout.write(JSON.stringify({ permission: "deny", user_message: msg, agent_message: msg }));
  } catch {
    process.stdout.write(JSON.stringify({ permission: "allow" }));
  }
});
