#!/usr/bin/env node
"use strict";

// Cursor beforeShellExecution hook for git push. Logic lives in ../../../hooks/core/push-gate.js;
// this file speaks Cursor's contract ({ permission, user_message, agent_message }).

const { gate, denyMessage, failsClosed, crashMessage } = require("../../../hooks/core/push-gate.js");
const { writeHookError } = require("../../../hooks/core/hook-log.js");

function respond(permission, msg) {
  const out = { permission };
  if (msg) {
    out.user_message = msg;
    out.agent_message = msg;
  }
  process.stdout.write(JSON.stringify(out));
}

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  let command = "";
  let cwd = process.cwd();
  try {
    const input = JSON.parse(raw || "{}");
    command = String(input.command || input.command_line || input.cmd || "");
    const roots = Array.isArray(input.workspace_roots) ? input.workspace_roots : [];
    cwd = String(input.cwd || input.working_directory || roots[0] || process.cwd());
    const failed = gate(command, cwd);
    if (!failed) {
      respond("allow");
      return;
    }
    respond("deny", denyMessage(failed.output, failed));
  } catch (err) {
    writeHookError("cursor:git-push-agentic-flow", err);
    // An unchecked push of the workflow repo is what this gate exists to stop.
    if (failsClosed(command, cwd)) respond("deny", crashMessage(err));
    else respond("allow");
  }
});
