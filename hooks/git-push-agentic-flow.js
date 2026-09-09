#!/usr/bin/env node
"use strict";

/**
 * Fail-closed gate for git push of this workflow repo.
 *
 * Cursor: beforeShellExecution (JSON in, { permission } out).
 * Claude: PreToolUse Bash (JSON in, hookSpecificOutput.permissionDecision).
 * Git:    hooks/git-hooks/pre-push calls this with --git-hook (exit 1 on fail).
 *
 * Windows work machines use powershell.exe; GitHub/home use pwsh.
 * When a PowerShell host is present, a failed assert denies the push.
 * When no host is on PATH, the hook skips (cannot run the .ps1) and CI still runs the same script.
 */

const { spawnSync } = require("child_process");
const path = require("path");

const REPO_ROOT = path.join(__dirname, "..");
const ASSERT = path.join(REPO_ROOT, "scripts", "ticket", "Assert-AgenticFlow.ps1");

function isGitPush(command) {
  return /\bgit(?:\.exe)?\s+push\b/i.test(String(command || ""));
}

function findPowerShell() {
  const names =
    process.platform === "win32" ? ["powershell.exe", "pwsh"] : ["pwsh"];
  for (const name of names) {
    const r = spawnSync(
      name,
      ["-NoProfile", "-NonInteractive", "-Command", "exit 0"],
      { timeout: 8000, encoding: "utf8" }
    );
    if (!r.error && r.status === 0) return name;
  }
  return null;
}

function runAssert() {
  const host = findPowerShell();
  if (!host) {
    // Cannot evaluate Assert-AgenticFlow.ps1 (Windows work machine has
    // powershell.exe; GitHub runners have pwsh). Do not fail-open on main
    // when a host exists — that path is fail-closed. No host: skip local
    // assert; GitHub Actions still runs the same script on PR/push.
    return {
      ok: true,
      skipped: true,
      output:
        "Assert-AgenticFlow skipped: no powershell.exe/pwsh on PATH. CI still runs it.",
    };
  }
  const r = spawnSync(
    host,
    ["-NoProfile", "-NonInteractive", "-File", ASSERT, "-Root", REPO_ROOT],
    { encoding: "utf8", timeout: 120000 }
  );
  const output = (String(r.stdout || "") + String(r.stderr || "")).trim();
  if (r.error) {
    return { ok: false, output: String(r.error.message || r.error) };
  }
  return { ok: r.status === 0, output };
}

function denyMessage(output) {
  const snippet = output ? output.slice(0, 1500) : "(no output)";
  return (
    "Push blocked: agentic-flow checks failed. Fix the violations, then push again.\n" +
    snippet
  );
}

function handleCursor(input) {
  const command = String(
    input.command || input.command_line || input.cmd || ""
  );
  if (!isGitPush(command)) {
    return { permission: "allow" };
  }
  const result = runAssert();
  if (result.ok) return { permission: "allow" };
  const msg = denyMessage(result.output);
  return {
    permission: "deny",
    user_message: msg,
    agent_message: msg,
  };
}

function handleClaude(input) {
  const toolInput = input.tool_input || {};
  const command = String(toolInput.command || "");
  if (!isGitPush(command)) return null;
  const result = runAssert();
  if (result.ok) return null;
  return {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: denyMessage(result.output),
    },
  };
}

function runGitHook() {
  const result = runAssert();
  if (result.ok) {
    if (result.output) process.stderr.write(result.output + "\n");
    process.exit(0);
  }
  process.stderr.write(denyMessage(result.output) + "\n");
  process.exit(1);
}

function main() {
  if (process.argv.indexOf("--git-hook") !== -1) {
    runGitHook();
    return;
  }

  let raw = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => {
    raw += chunk;
  });
  process.stdin.on("end", () => {
    try {
      const input = JSON.parse(raw || "{}");
      if (input.tool_input || input.hook_event_name === "PreToolUse") {
        const claude = handleClaude(input);
        if (claude) process.stdout.write(JSON.stringify(claude));
        process.exit(0);
        return;
      }
      process.stdout.write(JSON.stringify(handleCursor(input)));
    } catch (_err) {
      process.stdout.write(JSON.stringify({ permission: "allow" }));
    }
  });
}

main();
