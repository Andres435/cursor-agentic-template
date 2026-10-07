"use strict";

/**
 * Shared logic for the prompt-submit nudge (Cursor beforeSubmitPrompt, Claude UserPromptSubmit).
 *
 * Fires only when the prompt STARTS with a ticket slash command. A prompt or agent report
 * that merely mentions /complete-task, or uses the word "implement", gets nothing.
 *
 * IDE wording comes in through `verbs`, so this file names no IDE tool:
 *   verbs.exitPlan    how this IDE leaves plan mode before writer steps
 *   verbs.renameChat  optional sentence; omitted where the IDE cannot rename chats
 */

const COMMANDS = [
  "start-ticket",
  "implement",
  "review-changes",
  "complete-task",
  "prep-pr",
  "address-pr-comments",
];

// `/start-ticket`, `/<plugin>:start-ticket`, optionally after a leading `/engineering-mode`.
const LEAD = String.raw`^\s*(?:\/(?:[\w-]+:)?engineering-mode\s+)?\/(?:[\w-]+:)?`;

function leadingCommand(prompt) {
  const m = String(prompt || "").match(new RegExp(LEAD + "(" + COMMANDS.join("|") + ")\\b", "i"));
  return m ? m[1].toLowerCase() : null;
}

function startsWithEngineeringMode(prompt) {
  return /^\s*\/(?:[\w-]+:)?engineering-mode\b/i.test(String(prompt || ""));
}

function nudgesFor(prompt, verbs) {
  const v = verbs || {};
  const exitPlan = v.exitPlan || "leave plan mode";
  const command = leadingCommand(prompt);
  if (!command) return [];

  const bits = [];
  if (command === "complete-task" || command === "prep-pr") {
    bits.push(
      "Hours come from the manifest's startedAtUtc/completedAtUtc (legacy tickets: plans/WI-session.json) -- do not ask the user. The retrospective ASKS three questions and only writes what the user picks; the one unconditional output is a ledger row via scripts/Update-TicketLedger.ps1. Do not write a WI-closeout.md unless a finding earns a page. Run Assert-TicketArtifacts -Phase close only after the ledger row, never at chat start."
    );
  }
  if (command === "start-ticket") {
    bits.push(
      "Ask main tree vs worktree before any branch is created, and record mode on the manifest. Fan out one explore-repo subagent and one Search-CloseoutMemory.ps1 run per affected repo in the same batch as branch-setup; parent merges packets (max 8 priorFindings total). Do not Grep from source/repos root. Draft the plan in plan mode only; do not write the plan file until the user approves in chat. When revising the draft, re-emit only the section that changed. After the artifact gate passes, " +
        exitPlan +
        " before any Work Plan step. Do not report step N/M done while still in plan mode."
    );
  }
  if (command === "implement") {
    bits.push(
      "Only needed in a FRESH chat -- worktree mode, or resuming branch mode. If you are still in the chat that just approved the plan, keep building there. Run ticket-context-load first (Resolve-TicketRoot for mode/root, then manifest, approved plan, docSet) instead of re-planning. Append any plan-vs-reality change to the Deviations section of the plan file BEFORE reporting step N/M done. When profile.adrIndex is set, an accepted-decision conflict stops for the user, not a silent refinement."
    );
  }
  if (startsWithEngineeringMode(prompt)) {
    bits.push(
      "Engineering mode and a ticket command are in the same message. Read that command's playbook and execute it; do not improvise from the command name. Paths: skills/start-ticket/playbooks/start-ticket.md, skills/implement/playbooks/implement.md, skills/review-changes/playbooks/review-changes.md, skills/complete-task/playbooks/complete-task.md, skills/address-pr-comments/playbooks/address-pr-comments.md. Engineering mode only chooses the model. " +
        exitPlan +
        " before writer steps. Record ctxPct and the lane mix before the final message. A discarded lane's step still runs inline; say so once. Ticket commands load the tier contract on their own. Pin engineering mode for ad-hoc work or a long chat, not in the same message."
    );
  }
  if (v.renameChat && ["start-ticket", "review-changes", "complete-task", "implement"].indexOf(command) !== -1) {
    bits.push(v.renameChat);
  }
  return bits;
}

module.exports = { nudgesFor, leadingCommand, COMMANDS };
