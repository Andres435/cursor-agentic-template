"use strict";

/**
 * Fail-closed gate for git push of this workflow repo. Names no IDE.
 *
 * Only a push whose target repo is this workflow clone is gated; a push from any
 * other repo passes untouched. The gate runs that clone's own Assert-AgenticFlow.ps1, so an
 * installed plugin copy still checks the clone being pushed, not itself. When no PowerShell
 * host is on PATH the gate skips (cannot run the .ps1) and CI still runs it.
 */

const { spawnSync } = require("child_process");
const path = require("path");
const { gitCalls, workflowRoot, ASSERT_REL } = require("./git-target.js");

/** Directories a command pushes from (see git-target.js for what counts as a push). */
function pushDirs(command, cwd) {
  return gitCalls(command, cwd, "push").map((call) => call.dir);
}

function findPowerShell() {
  // Assert-AgenticFlow requires PowerShell 7, so try pwsh first.
  const names = process.platform === "win32" ? ["pwsh", "powershell.exe"] : ["pwsh"];
  for (const name of names) {
    const r = spawnSync(name, ["-NoProfile", "-NonInteractive", "-Command", "exit 0"], {
      timeout: 8000,
      encoding: "utf8",
    });
    if (!r.error && r.status === 0) return name;
  }
  return null;
}

function runAssert(root) {
  const host = findPowerShell();
  if (!host) {
    return {
      ok: true,
      skipped: true,
      output: "Assert-AgenticFlow skipped: no pwsh/powershell.exe on PATH. CI still runs it.",
    };
  }
  const r = spawnSync(
    host,
    ["-NoProfile", "-NonInteractive", "-File", path.join(root, ASSERT_REL), "-Root", root],
    { encoding: "utf8", timeout: 120000 }
  );
  const output = (String(r.stdout || "") + String(r.stderr || "")).trim();
  if (r.error) return { ok: false, output: String(r.error.message || r.error) };
  return { ok: r.status === 0, output };
}

/** Gate every workflow clone the command pushes; null when nothing failed. */
function gate(command, cwd) {
  const roots = [];
  for (const dir of pushDirs(command, cwd)) {
    const root = workflowRoot(dir);
    if (root && roots.indexOf(root) === -1) roots.push(root);
  }
  for (const root of roots) {
    const result = runAssert(root);
    if (!result.ok) return result;
  }
  return null;
}

function denyMessage(output) {
  const snippet = output ? output.slice(0, 1500) : "(no output)";
  return "Push blocked: agentic-flow checks failed. Fix the violations, then push again.\n" + snippet;
}

module.exports = { gate, runAssert, denyMessage, pushDirs, workflowRoot };
