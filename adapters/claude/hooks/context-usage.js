#!/usr/bin/env node
"use strict";

// Claude Code Stop hook. After each turn, records this chat's measured context occupancy
// from the transcript (report-context, ../../../hooks/core/context-usage.js) so
// Set-TicketCtxPct.ps1 can use a real number instead of an estimate. Never blocks; no output.

const { record, fromTranscript } = require("../../../hooks/core/context-usage.js");

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const pct = input.transcript_path ? fromTranscript(input.transcript_path) : null;
    if (pct !== null) record(input.session_id, pct, "claude-transcript");
  } catch {
    // best effort
  }
  process.exit(0);
});
