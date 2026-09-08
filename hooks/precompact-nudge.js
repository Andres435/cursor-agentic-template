#!/usr/bin/env node
"use strict";

/**
 * preCompact — observational only. Reminds the user to re-hydrate ticket
 * state after compact, and surfaces context_usage_percent so complete-task
 * can copy Ctx% instead of guessing.
 */

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});

process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const pct = Number(input.context_usage_percent);
    const fromPath = (process.env.CURSOR_PROJECT_DIR || process.cwd()).match(
      /\bWI(\d{4,})\b/i
    );
    const wi = process.env.TMO_TICKET || (fromPath ? "WI" + fromPath[1] : null);
    const bits = [];
    if (Number.isFinite(pct)) bits.push("Ctx% " + Math.round(pct));
    if (wi) bits.push("re-run ticket-context-load for " + wi + " after compact");

    if (!bits.length) {
      process.stdout.write("{}");
      return;
    }

    process.stdout.write(JSON.stringify({ user_message: bits.join(" — ") }));
  } catch {
    process.stdout.write("{}");
  }
});
