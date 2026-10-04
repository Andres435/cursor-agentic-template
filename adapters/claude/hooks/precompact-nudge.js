#!/usr/bin/env node
"use strict";

// Claude Code PreCompact hook. Observational only -- never blocks the compact.
// Records this chat's measured context from the transcript (report-context,
// ../../../hooks/core/context-usage.js) and reminds the agent to re-hydrate the ticket.
// The ticket is recovered from cwd / CLAUDE_PROJECT_DIR / TMO_TICKET.

const { record, fromTranscript } = require("../../../hooks/core/context-usage.js");
const { detectTicket, loadProfile } = require("../../../hooks/core/session-context.js");

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    try {
      const pct = input.transcript_path ? fromTranscript(input.transcript_path) : null;
      if (pct !== null) record(input.session_id, pct, "claude-transcript");
    } catch {
      // measuring is best effort
    }
    const ticket = detectTicket(
      [input.cwd, process.env.CLAUDE_PROJECT_DIR, process.env.TMO_TICKET, process.cwd()],
      loadProfile()
    );
    if (!ticket) {
      process.exit(0);
      return;
    }
    const wi = ticket;
    process.stdout.write(
      JSON.stringify({
        systemMessage:
          "Compacting — re-run ticket-context-load for " +
          wi +
          " before continuing so manifest, approved plan, and docSet are back in context.",
      })
    );
  } catch {
    process.exit(0);
  }
});
