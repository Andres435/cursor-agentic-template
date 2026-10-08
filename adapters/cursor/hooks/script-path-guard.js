#!/usr/bin/env node
"use strict";

// Cursor beforeShellExecution hook for running a .ps1/.py outside source\repos\. The decision is
// ../../../hooks/core/script-path-guard.js; this file speaks { permission, user_message, agent_message }.

const { decideRun } = require("../../../hooks/core/script-path-guard.js");
const { writeHookError } = require("../../../hooks/core/hook-log.js");

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const d = decideRun(String(input.command || input.command_line || input.cmd || ""));
    if (!d) {
      process.stdout.write(JSON.stringify({ permission: "allow" }));
      return;
    }
    process.stdout.write(JSON.stringify({ permission: "deny", user_message: d.reason, agent_message: d.reason }));
  } catch (err) {
    writeHookError("cursor:script-path-guard", err);
    process.stdout.write(JSON.stringify({ permission: "allow" }));
  }
});
