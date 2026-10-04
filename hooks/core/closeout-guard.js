"use strict";

/**
 * Closeout dump guard. Denies direct reads of plans/WI*-closeout.md and
 * plans/closeout-index.md so memory stays retrieval via Search-CloseoutMemory.ps1
 * (max 8 {ticket, lesson} rows). Names no IDE.
 */

const DENY_MSG =
  "Direct read of a closeout file is blocked to keep memory retrieval-based. " +
  "Run scripts/ticket/Search-CloseoutMemory.ps1 -Ticket WI<n> or -Query <term> " +
  "to get at most 8 focused {ticket, lesson} rows. Do not read " +
  "plans/closeout-index.md or any WI*-closeout.md directly.";

function isCloseoutDump(filePath) {
  return /[/\\](?:WI\d+-closeout|closeout-index)\.md$/i.test(String(filePath || ""));
}

module.exports = { isCloseoutDump, DENY_MSG };
