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
        "Default mode is branch (canonical clones, plan and build in ONE chat); --worktree is the special case. Record mode on the manifest. Fan out one explore-repo subagent and one Search-CloseoutMemory.ps1 run per affected repo in the same batch as branch-setup; parent merges packets (max 8 priorFindings total). Do not Grep from source/repos root. Draft the plan in Plan mode only; do not write the plan file until the user approves in chat, and never trigger Plan mode's native Build action. When revising the draft, re-emit only the section that changed."
      );
    }
    if (/\bimplement\b/i.test(prompt)) {
      bits.push(
        "Only needed in a FRESH chat -- worktree mode, or resuming branch mode. If you are still in the chat that just approved the plan, keep building there. Run ticket-context-load first (Resolve-TicketRoot for mode/root, then manifest, approved plan, docSet) instead of re-planning. Append any plan-vs-reality change to the Deviations section of the plan file BEFORE reporting step N/M done. An ADR conflict stops for the user, not a silent refinement."
      );
    }

    // rename_chat nudge: Cursor has access to cursor-app-control.rename_chat
    if (/start-ticket|review-changes|complete-task|\bimplement\b/i.test(prompt)) {
      bits.push(
        "Rename this chat to 'WI##### <phase>' using cursor-app-control rename_chat so the user can navigate multiple open tabs."
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
