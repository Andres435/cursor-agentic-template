"use strict";

/**
 * Swallowed hook errors land here so /doctor can see them. A hook still never
 * throws. Missing files (ENOENT) are normal and are not logged.
 * File: scripts/.hook-errors.log (gitignored), or TMO_HOOK_ERRORS_FILE (tests).
 */

const fs = require("fs");
const path = require("path");

const DEFAULT_LOG = path.join(__dirname, "..", "..", "scripts", ".hook-errors.log");

function writeHookError(hook, error) {
  try {
    if (error && error.code === "ENOENT") return;
    const message = error && error.message ? String(error.message) : String(error || "unknown");
    const line = JSON.stringify({
      hook: String(hook || "hook"),
      message: message,
      at: new Date().toISOString(),
    }) + "\n";
    const file = process.env.TMO_HOOK_ERRORS_FILE || DEFAULT_LOG;
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.appendFileSync(file, line);
  } catch {
    // the log itself must never throw into the hook
  }
}

module.exports = { writeHookError };
