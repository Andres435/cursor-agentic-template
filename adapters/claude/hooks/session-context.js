#!/usr/bin/env node
"use strict";

// Claude Code SessionStart hook. Logic lives in ../../../hooks/core/session-context.js; this
// file speaks Claude's contract: cwd on stdin, hookSpecificOutput.additionalContext on stdout.
// The TMO_* env block (Cursor's hook `env`) goes to CLAUDE_ENV_FILE when Claude provides it,
// plus TMO_SESSION_ID so Set-TicketCtxPct.ps1 can pick this chat's measured context.

const fs = require("fs");
const { buildPacket } = require("../../../hooks/core/session-context.js");

function exportEnv(env) {
  const file = process.env.CLAUDE_ENV_FILE;
  if (!file) return;
  const lines = Object.keys(env)
    .filter((k) => env[k])
    .map((k) => "export " + k + "=" + JSON.stringify(String(env[k])));
  if (lines.length) fs.appendFileSync(file, lines.join("\n") + "\n");
}

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const packet = buildPacket([input.cwd, process.env.CLAUDE_PROJECT_DIR, process.cwd()]);
    try {
      exportEnv(Object.assign({ TMO_SESSION_ID: input.session_id || "" }, packet ? packet.env : {}));
    } catch {
      // env export is best effort
    }
    if (!packet) {
      process.exit(0);
      return;
    }
    process.stdout.write(
      JSON.stringify({
        hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: packet.text },
      })
    );
  } catch {
    process.exit(0);
  }
});
