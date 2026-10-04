#!/usr/bin/env node
"use strict";

// Cursor sessionStart hook. Logic lives in ../../../hooks/core/session-context.js; this file
// speaks Cursor's contract: workspace_roots on stdin, { additional_context, env } on stdout.
// additional_context can be dropped by a known Cursor race, so env is also set for later
// hooks in this session (TMO_TICKET / TMO_MODE / TMO_ROOT / TMO_PROFILE / ...).

const { buildPacket } = require("../../../hooks/core/session-context.js");

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const roots = Array.isArray(input.workspace_roots) ? input.workspace_roots : [];
    const packet = buildPacket([...roots, process.env.CURSOR_PROJECT_DIR, process.cwd()]);
    if (!packet) {
      process.stdout.write("{}");
      return;
    }
    process.stdout.write(JSON.stringify({ additional_context: packet.text, env: packet.env }));
  } catch {
    process.stdout.write("{}");
  }
});
