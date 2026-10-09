"use strict";

/**
 * Decision for a shell command that runs git add or git commit. Names no IDE; the
 * Cursor and Claude hooks translate { action, reason } into their own contracts.
 *
 *   deny  a commit in any repo that adds a token-shaped secret (secret-scan.js).
 *   deny  git add -f of a user-local plans/ file, or a commit with one staged, in a
 *         workflow repo clone. Ticket manifests, plans and the ledger never enter git.
 *   ask   a commit in a product repo whose message has no work-item id.
 *   allow everything else. Workflow-repo commits carry no ticket, so they are not asked.
 */

const fs = require("fs");
const path = require("path");
const { gitCalls, workflowRoot, stagedUserPlans, unquote } = require("./git-target.js");
const { detectTicket, loadProfile } = require("./session-context.js");
const { scanRepo, describe: describeSecrets } = require("./secret-scan.js");

const PLANS_RULE =
  "plans/ ticket files (manifests, plans, feedback, ledger) are user-local and never committed. " +
  "Only plans/README.md, plans/closeout-index.md, plans/workflow-template-plan.md and plans/examples/ are tracked.";

function forcedPlansPath(args) {
  const tokens = String(args || "").split(/\s+/);
  const forced = tokens.some((t) => t === "-f" || t === "--force" || /^-[a-zA-Z]*f[a-zA-Z]*$/.test(t));
  if (!forced) return null;
  return tokens.find((t) => /^["']?(?:\.[\\/])?plans(?:[\\/]|["']?$)/.test(t)) || null;
}

const MESSAGE_FILE = /(?:^|\s)(?:-F|--file)(?:=|\s+)("[^"]+"|'[^']+'|\S+)/;

/**
 * True when this commit's own message names a work item (profile.ticketPrefix + digits): the
 * -m/--message text, or the contents of a -F/--file message file, or for `-F -` the stdin text
 * (heredoc / here-string) that follows the commit in the command. A ticket id in the directory
 * (`cd .../<ticket> && git commit`) or the file path does not count.
 */
function messageNamesTicket(call, command, profile) {
  const names = (text) => Boolean(detectTicket([text], profile));
  const args = String(call.args || "");
  const file = args.match(MESSAGE_FILE);
  if (file && unquote(file[1]) === "-") {
    const at = String(command || "").search(/\bcommit\b/i);
    return at >= 0 && names(String(command).slice(at));
  }
  if (file) {
    try {
      if (names(fs.readFileSync(path.resolve(call.dir, unquote(file[1])), "utf8"))) return true;
    } catch {
      // unreadable message file: fall through to the inline message, if any
    }
  }
  return names(args.replace(MESSAGE_FILE, " "));
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

  // Secrets: any repo, not just this one. A git add in the same command or commit -a means
  // unstaged edits are about to be recorded too.
  const addsFirst = gitCalls(command, cwd, "add").length > 0;
  for (const call of commits) {
    const all = /(?:^|\s)(?:-[a-zA-Z]*a[a-zA-Z]*|--all)(?=\s|$)/.test(String(call.args || ""));
    const hits = scanRepo(call.dir, addsFirst || all);
    if (hits.length) return { action: "deny", reason: describeSecrets(hits) };
  }

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
  const productCommits = commits.filter((call) => !workflowRoot(call.dir));
  const profile = loadProfile();
  if (!productCommits.length || productCommits.every((call) => messageNamesTicket(call, command, profile))) {
    return { action: "allow" };
  }

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
