"use strict";

/**
 * Session-start packet: compact profile + ticket-tree hydration. Names no IDE.
 *
 * Always carries { profileId, ticketSystem, layout } from profile.json when present.
 * Detects a ticket from the given folder hints using profile.ticketPrefix (default WI),
 * runs Resolve-TicketRoot.ps1 -Ticket <id> -Json, and adds mode, root, rootExists, repos[]
 * and the next action. Adapters turn { label, compact, env } into their own output.
 */

const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const REPO_ROOT = path.join(__dirname, "..", "..");

function loadProfile() {
  const candidates = [
    path.join(REPO_ROOT, "profile.json"),
    path.join(process.cwd(), "profile.json"),
    path.join(process.cwd(), "tmo-agentic", "profile.json"),
  ];
  for (const candidate of candidates) {
    try {
      return JSON.parse(fs.readFileSync(candidate, "utf8"));
    } catch {
      // try next
    }
  }
  return null;
}

function detectTicket(hints, profile) {
  const text = hints.filter(Boolean).join(" ");
  const configured = String((profile && profile.ticketPrefix) || "WI");
  const prefixes = configured === "WI" ? ["WI"] : [configured, "WI"];
  for (const prefix of prefixes) {
    const escaped = prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const match = text.match(new RegExp("\\b" + escaped + "(\\d+)\\b", "i"));
    if (match) return prefix + match[1];
  }
  return null;
}

function resolveScript() {
  const nextToScripts = path.join(REPO_ROOT, "scripts", "Resolve-TicketRoot.ps1");
  const ticketFolder = path.join(REPO_ROOT, "scripts", "ticket", "Resolve-TicketRoot.ps1");
  return fs.existsSync(nextToScripts) ? nextToScripts : ticketFolder;
}

function runResolve(ticket) {
  const scriptPath = resolveScript();
  if (!fs.existsSync(scriptPath)) return null;
  // pwsh first; Windows PowerShell only when pwsh is not installed, so a slow
  // resolve can never run twice and outlast the hook timeout.
  const shells = process.platform === "win32" ? ["pwsh", "powershell"] : ["pwsh"];
  for (const shell of shells) {
    try {
      const result = execFileSync(
        shell,
        ["-NoProfile", "-NonInteractive", "-File", scriptPath, "-Ticket", ticket, "-Json"],
        { timeout: 6000, encoding: "utf8" }
      );
      return JSON.parse(String(result).trim());
    } catch (err) {
      if (!err || err.code !== "ENOENT") return null;
    }
  }
  return null;
}

/**
 * manifest missing                       → "start-ticket"
 * manifest exists, no reviewReady stamp  → "review-changes (stage first)"
 * reviewReady set, completedAtUtc null   → "complete-task"
 * completedAtUtc set                     → "closed"
 * TMO_PLANS_DIR overrides plans/ (tests).
 */
function resolveNextAction(ticket) {
  const plansDir = process.env.TMO_PLANS_DIR || path.join(REPO_ROOT, "plans");
  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(path.join(plansDir, ticket + "-manifest.json"), "utf8"));
  } catch {
    return "start-ticket";
  }
  if (manifest.completedAtUtc) return "closed";
  if (manifest.reviewReady) return "complete-task";
  return "review-changes (stage first)";
}

/** null when there is nothing to say; otherwise { label, compact, env, text }. */
function buildPacket(hints) {
  const profile = loadProfile();
  const slice = profile
    ? { profileId: profile.id || null, ticketSystem: profile.ticketSystem || null, layout: profile.layout || null }
    : null;
  const ticket = detectTicket(hints, profile);
  if (!ticket && !slice) return null;

  const compact = {};
  if (slice) Object.assign(compact, slice);
  if (ticket) {
    compact.ticket = ticket;
    const packet = runResolve(ticket);
    if (packet) {
      compact.mode = packet.mode;
      compact.root = packet.root;
      compact.rootExists = packet.rootExists;
      compact.repos = packet.repos;
    }
    compact.nextAction = resolveNextAction(ticket);
  }
  const label = ticket ? "Ticket tree for " + ticket : "Profile";
  const env = {
    TMO_TICKET: ticket || "",
    TMO_MODE: compact.mode ? String(compact.mode) : "",
    TMO_ROOT: compact.root ? String(compact.root) : "",
    TMO_PROFILE: slice && slice.profileId ? String(slice.profileId) : "",
    TMO_TICKET_SYSTEM: slice && slice.ticketSystem ? String(slice.ticketSystem) : "",
    TMO_LAYOUT: slice && slice.layout ? String(slice.layout) : "",
  };
  return { label, compact, env, text: label + ": " + JSON.stringify(compact) };
}

module.exports = { buildPacket, detectTicket, loadProfile, resolveNextAction };
