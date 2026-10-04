#!/usr/bin/env node
"use strict";

// Cursor preCompact hook. Observational only. Records the measured context_usage_percent
// (report-context, ../../../hooks/core/context-usage.js) and reminds the user to re-hydrate
// ticket state after compact.

const { record } = require("../../../hooks/core/context-usage.js");
const { detectTicket, loadProfile } = require("../../../hooks/core/session-context.js");

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const pct = Number(input.context_usage_percent);
    if (Number.isFinite(pct)) {
      try {
        record(input.conversation_id || input.session_id || "", pct, "cursor-precompact");
      } catch {
        // measuring is best effort; never block the compact
      }
    }
    const wi =
      process.env.TMO_TICKET ||
      detectTicket([process.env.CURSOR_PROJECT_DIR, process.cwd()], loadProfile());
    const bits = [];
    if (Number.isFinite(pct)) bits.push("Ctx% " + Math.round(pct));
    if (wi) bits.push("re-run ticket-context-load for " + wi + " after compact");
    process.stdout.write(bits.length ? JSON.stringify({ user_message: bits.join(" — ") }) : "{}");
  } catch {
    process.stdout.write("{}");
  }
});
