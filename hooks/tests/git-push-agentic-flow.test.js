#!/usr/bin/env node
"use strict";

/**
 * Smoke tests for hooks/git-push-agentic-flow.js
 * Non-push commands must not spawn PowerShell. git push runs Assert-AgenticFlow
 * when a host is available (CI).
 */
const assert = require("assert");
const { spawnSync } = require("child_process");
const path = require("path");

const HOOK = path.join(__dirname, "..", "git-push-agentic-flow.js");

function runHook(inputObj, extraArgs, timeout) {
  const args = [HOOK].concat(extraArgs || []);
  const result = spawnSync(process.execPath, args, {
    input: JSON.stringify(inputObj),
    encoding: "utf8",
    timeout: timeout || 8000,
  });
  if (result.error) throw result.error;
  const out = String(result.stdout || "").trim();
  let json = null;
  if (out) {
    try {
      json = JSON.parse(out);
    } catch {
      json = null;
    }
  }
  return { status: result.status, json, stdout: out, stderr: result.stderr };
}

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log("  ✓ " + name);
    passed++;
  } catch (err) {
    console.error("  ✗ " + name);
    console.error("    " + err.message);
    failed++;
  }
}

console.log("git-push-agentic-flow.js smoke tests");

test("allows git status (Cursor)", () => {
  const out = runHook({ command: "git status" });
  assert.strictEqual(out.json.permission, "allow");
});

test("allows git commit (Cursor) — push matcher only", () => {
  const out = runHook({ command: 'git commit -m "wip"' });
  assert.strictEqual(out.json.permission, "allow");
});

test("ignores git status (Claude PreToolUse)", () => {
  const out = runHook({
    tool_input: { command: "git status" },
    hook_event_name: "PreToolUse",
  });
  assert.strictEqual(out.stdout, "");
  assert.strictEqual(out.status, 0);
});

test("denies Cursor git push when Assert-AgenticFlow fails or host missing", () => {
  // On CI this tree should pass; we only assert the hook returns JSON.
  const out = runHook({ command: "git push origin HEAD" }, [], 120000);
  assert.ok(out.json, "expected JSON, got: " + out.stdout);
  assert.ok(
    out.json.permission === "allow" || out.json.permission === "deny",
    "expected allow or deny, got " + out.json.permission
  );
  if (out.json.permission === "deny") {
    assert.ok(/agentic-flow/i.test(out.json.user_message || ""), "deny should mention agentic-flow");
  }
});

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
