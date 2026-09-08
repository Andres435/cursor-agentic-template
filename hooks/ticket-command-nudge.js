#!/usr/bin/env node
"use strict";

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const prompt = String(
      input.prompt || input.content || input.text || JSON.stringify(input)
    );

    const bits = [];
    if (/complete-task|prep-pr/i.test(prompt)) {
      bits.push(
        "Hours come from the manifest's startedAtUtc/completedAtUtc (legacy tickets: plans/WI-session.json) -- do not ask the user. The retrospective ASKS three questions and only writes what the user picks; the one unconditional output is a ledger row via scripts/Update-TicketLedger.ps1. Do not write a WI-closeout.md unless a finding earns a page. Run Assert-TicketArtifacts -Phase close only after the ledger row, never at chat start."
      );
    }
    if (/start-ticket/i.test(prompt)) {
      bits.push(
        "Default mode is branch (canonical clones, plan and build in ONE chat); --worktree is the special case. Record mode on the manifest. ticket-router must run Search-CloseoutMemory.ps1 (or grep plans/closeout-index.md) and put at most 8 priorFindings on the manifest. Draft the plan in Plan mode only; do not write the plan file until the user approves in chat, and never trigger Plan mode's native Build action. When revising the draft, re-emit only the section that changed."
      );
    }
    if (/\bimplement\b/i.test(prompt)) {
      bits.push(
        "Only needed in a FRESH chat -- worktree mode, or resuming branch mode. If you are still in the chat that just approved the plan, keep building there. Run ticket-context-load first (Resolve-TicketRoot for mode/root, then manifest, approved plan, docSet) instead of re-planning. Log any plan-vs-reality change to the plan file's Deviations section. For TmoPro, an Accepted ADR conflict stops for the user, not a silent refinement."
      );
    }

    if (bits.length) {
      process.stdout.write(
        JSON.stringify({ additional_context: bits.join(" ") })
      );
      return;
    }
    process.stdout.write("{}");
  } catch (_err) {
    process.stdout.write("{}");
  }
});
