#!/usr/bin/env node
"use strict";

/**
 * beforeReadFile hook — closeout dump guard.
 *
 * Matcher is the tool type (Read), not the path. Path filtering is here.
 * Denies plans/WI*-closeout.md and plans/closeout-index.md so memory stays
 * retrieval via Search-CloseoutMemory.ps1 (max 8 {ticket, lesson} rows).
 */

const DENY_MSG =
  "Direct read of a closeout file is blocked to keep memory retrieval-based. " +
  "Run scripts/ticket/Search-CloseoutMemory.ps1 -Ticket WI<n> or -Query <term> " +
  "to get at most 8 focused {ticket, lesson} rows. Do not read " +
  "plans/closeout-index.md or any WI*-closeout.md directly.";

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});

process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const filePath = String(input.file_path || input.path || input.filename || "");

    const isCloseoutDump = /[/\\](?:WI\d+-closeout|closeout-index)\.md$/i.test(
      filePath
    );

    if (!isCloseoutDump) {
      process.stdout.write(JSON.stringify({ permission: "allow" }));
      return;
    }

    process.stdout.write(
      JSON.stringify({
        permission: "deny",
        user_message: DENY_MSG,
        agent_message: DENY_MSG,
      })
    );
  } catch {
    process.stdout.write(JSON.stringify({ permission: "allow" }));
  }
});
