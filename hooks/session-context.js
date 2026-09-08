#!/usr/bin/env node
"use strict";

/**
 * sessionStart hook — compact ticket-tree hydration.
 *
 * Detects WI<n> from workspace_roots (common envelope), CURSOR_PROJECT_DIR,
 * or cwd. Runs Resolve-TicketRoot.ps1 -Ticket WI<n> -Json and injects that
 * packet only: mode, root, rootExists, repos[].
 *
 * additional_context can be dropped by a known Cursor race; env is also set
 * so later hooks in this session still see TMO_TICKET / TMO_MODE / TMO_ROOT.
 */

const { execFileSync } = require("child_process");
const path = require("path");

function detectTicket(input) {
  const roots = Array.isArray(input.workspace_roots) ? input.workspace_roots : [];
  const candidates = [
    ...roots,
    process.env.CURSOR_PROJECT_DIR,
    process.env.CLAUDE_PROJECT_DIR,
    process.cwd(),
  ]
    .filter(Boolean)
    .join(" ");

  const match = candidates.match(/\bWI(\d{4,})\b/i);
  return match ? "WI" + match[1] : null;
}

function resolveScript() {
  return path.join(__dirname, "..", "scripts", "Resolve-TicketRoot.ps1");
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

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});

process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const ticket = detectTicket(input);
    if (!ticket) {
      process.stdout.write("{}");
      return;
    }

    const packet = runResolve(ticket);
    const compact = packet
      ? {
          ticket,
          mode: packet.mode,
          root: packet.root,
          rootExists: packet.rootExists,
          repos: packet.repos,
        }
      : { ticket };

    const out = {
      additional_context: "Ticket tree for " + ticket + ": " + JSON.stringify(compact),
      env: {
        TMO_TICKET: ticket,
        TMO_MODE: compact.mode ? String(compact.mode) : "",
        TMO_ROOT: compact.root ? String(compact.root) : "",
      },
    };
    process.stdout.write(JSON.stringify(out));
  } catch {
    process.stdout.write("{}");
  }
});
