#!/usr/bin/env node
"use strict";

// Cursor beforeReadFile hook. The matcher is the tool type (Read); the path filter is
// ../../../hooks/core/closeout-guard.js. Speaks { permission, user_message, agent_message }.

const { isCloseoutDump, DENY_MSG } = require("../../../hooks/core/closeout-guard.js");

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const filePath = String(input.file_path || input.path || input.filename || "");
    if (!isCloseoutDump(filePath)) {
      process.stdout.write(JSON.stringify({ permission: "allow" }));
      return;
    }
    process.stdout.write(JSON.stringify({ permission: "deny", user_message: DENY_MSG, agent_message: DENY_MSG }));
  } catch {
    process.stdout.write(JSON.stringify({ permission: "allow" }));
  }
});
