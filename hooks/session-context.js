#!/usr/bin/env node
"use strict";

/**
 * sessionStart hook — compact profile + ticket-tree hydration.
 *
 * Always injects { profileId, ticketSystem, layout } from profile.json when present.
 * Detects a ticket from workspace_roots / CURSOR_PROJECT_DIR / cwd using
 * profile.ticketPrefix (default WI). Runs Resolve-TicketRoot.ps1 -Ticket <id> -Json
 * and appends that packet: mode, root, rootExists, repos[].
 *
 * additional_context can be dropped by a known Cursor race; env is also set
 * so later hooks in this session still see TMO_TICKET / TMO_MODE / TMO_ROOT
 * plus TMO_PROFILE / TMO_TICKET_SYSTEM / TMO_LAYOUT.
 */

const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");

function loadProfile() {
  const candidates = [
    path.join(__dirname, "..", "profile.json"),
    path.join(process.cwd(), "profile.json"),
    path.join(process.cwd(), ".cursor", "profile.json"),
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

function detectTicket(input, profile) {
  const prefix = String((profile && profile.ticketPrefix) || "WI");
  const escaped = prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const re = new RegExp("\\b" + escaped + "(\\d+)\\b", "i");

  const roots = Array.isArray(input.workspace_roots) ? input.workspace_roots : [];
  const candidates = [
    ...roots,
    process.env.CURSOR_PROJECT_DIR,
    process.env.CLAUDE_PROJECT_DIR,
    process.cwd(),
  ]
    .filter(Boolean)
    .join(" ");

  const match = candidates.match(re);
  return match ? prefix + match[1] : null;
}

function resolveScript() {
  const nextToHooks = path.join(__dirname, "..", "scripts", "Resolve-TicketRoot.ps1");
  const ticketFolder = path.join(
    __dirname,
    "..",
    "scripts",
    "ticket",
    "Resolve-TicketRoot.ps1"
  );
  return fs.existsSync(nextToHooks) ? nextToHooks : ticketFolder;
}

function runResolve(ticket) {
  const scriptPath = resolveScript();
  const shells =
    process.platform === "win32" ? ["pwsh", "powershell"] : ["pwsh"];

  for (const shell of shells) {
    try {
      const result = execFileSync(
        shell,
        [
          "-NoProfile",
          "-NonInteractive",
          "-File",
          scriptPath,
          "-Ticket",
          ticket,
          "-Json",
        ],
        { timeout: 8000, encoding: "utf8" }
      );
      return JSON.parse(String(result).trim());
    } catch {
      // try next shell, or degrade
    }
  }
  return null;
}

function profileSlice(profile) {
  if (!profile) return null;
  return {
    profileId: profile.id || null,
    ticketSystem: profile.ticketSystem || null,
    layout: profile.layout || null,
  };
}

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});

process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const profile = loadProfile();
    const slice = profileSlice(profile);
    const ticket = detectTicket(input, profile);

    if (!ticket && !slice) {
      process.stdout.write("{}");
      return;
    }

    const packet = ticket ? runResolve(ticket) : null;
    const compact = {};
    if (slice) Object.assign(compact, slice);
    if (ticket) {
      compact.ticket = ticket;
      if (packet) {
        compact.mode = packet.mode;
        compact.root = packet.root;
        compact.rootExists = packet.rootExists;
        compact.repos = packet.repos;
      }
    }

    const label = ticket ? "Ticket tree for " + ticket : "Profile";
    const out = {
      additional_context: label + ": " + JSON.stringify(compact),
      env: {
        TMO_TICKET: ticket || "",
        TMO_MODE: compact.mode ? String(compact.mode) : "",
        TMO_ROOT: compact.root ? String(compact.root) : "",
        TMO_PROFILE: slice && slice.profileId ? String(slice.profileId) : "",
        TMO_TICKET_SYSTEM:
          slice && slice.ticketSystem ? String(slice.ticketSystem) : "",
        TMO_LAYOUT: slice && slice.layout ? String(slice.layout) : "",
      },
    };
    process.stdout.write(JSON.stringify(out));
  } catch {
    process.stdout.write("{}");
  }
});
