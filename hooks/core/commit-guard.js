"use strict";

/**
 * Decision for a shell command that runs git add or git commit. Names no IDE; the
 * Cursor and Claude hooks translate { action, reason } into their own contracts.
 *
 *   deny  git add -f of a user-local plans/ file, or a commit with one staged, in a
 *         tmo-agentic clone. Ticket manifests, plans and the ledger never enter git.
 *   ask   a commit in a product repo whose message has no work-item id.
 *   allow everything else. Workflow-repo commits carry no ticket, so they are not asked.
 */

const { gitCalls, workflowRoot, stagedUserPlans } = require("./git-target.js");
const { detectTicket, loadProfile } = require("./session-context.js");

const PLANS_RULE =
  "plans/ ticket files (manifests, plans, feedback, ledger) are user-local and never committed. " +
  "Only plans/README.md, plans/closeout-index.md, plans/workflow-template-plan.md and plans/examples/ are tracked.";

function forcedPlansPath(args) {
  const tokens = String(args || "").split(/\s+/);
  const forced = tokens.some((t) => t === "-f" || t === "--force" || /^-[a-zA-Z]*f[a-zA-Z]*$/.test(t));
  if (!forced) return null;
  return tokens.find((t) => /^["']?(?:\.[\\/])?plans(?:[\\/]|["']?$)/.test(t)) || null;
}

function decide(event) {
  const command = String((event && event.command) || "");
  const cwd = String((event && event.cwd) || process.cwd());

  for (const call of gitCalls(command, cwd, "add")) {
    const hit = forcedPlansPath(call.args);
    if (hit && workflowRoot(call.dir)) {
      return { action: "deny", reason: "Blocked `git add -f " + hit + "`. " + PLANS_RULE };
    }
  }

  const commits = gitCalls(command, cwd, "commit");
  if (!commits.length) return { action: "allow" };

  for (const call of commits) {
    const root = workflowRoot(call.dir);
    if (!root) continue;
    const staged = stagedUserPlans(root);
    if (staged.length) {
      return {
        action: "deny",
        reason: "Commit blocked: " + staged.join(", ") + " is staged. Unstage it (git restore --staged plans). " + PLANS_RULE,
      };
    }
  }

  // Product-repo commits name their ticket; workflow-repo commits have none to name.
  const productCommit = commits.some((call) => !workflowRoot(call.dir));
  const profile = loadProfile();
  if (!productCommit || detectTicket([command], profile)) return { action: "allow" };

  const cwdTicket = detectTicket([cwd], profile);
  const suggested = cwdTicket || String((profile && profile.ticketPrefix) || "WI") + "#####";
  return {
    action: "ask",
    reason:
      "Commit message has no work-item id. Include " +
      suggested +
      " (example: fix(legacy): describe change [" +
      suggested +
      "]).",
    suggested,
  };
}

module.exports = { decide, PLANS_RULE };
