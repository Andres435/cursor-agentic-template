#!/usr/bin/env node
"use strict";

/**
 * Smoke tests for hooks/git-push-agentic-flow.js
 * Non-push commands must not spawn PowerShell. git push runs Assert-AgenticFlow
 * when a host is available (CI).
 */
const assert = require("assert");
const { spawnSync } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const HOOK = path.join(__dirname, "..", "..", "adapters", "cursor", "hooks", "git-push-agentic-flow.js");
const WORKFLOW_ROOT = path.resolve(__dirname, "..", "..");
const { pushDirs, workflowRoot } = require("../core/push-gate.js");

// A throwaway git repo that is not the workflow repo (stands in for TmoPro).
const OTHER_REPO = fs.mkdtempSync(path.join(os.tmpdir(), "push-gate-"));
spawnSync("git", ["-C", OTHER_REPO, "init", "-q"]);

// The Claude adapter speaks PreToolUse; the Cursor one speaks beforeShellExecution.
const CLAUDE_HOOK = path.join(__dirname, "..", "..", "adapters", "claude", "hooks", "git-push-agentic-flow.js");

function runHook(inputObj, extraArgs, timeout) {
  const hook = inputObj.tool_input ? CLAUDE_HOOK : HOOK;
  const args = [hook].concat(extraArgs || []);
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

test("pushDirs ignores git push that is not a command", () => {
  assert.deepStrictEqual(pushDirs('echo "git push origin HEAD"', OTHER_REPO), []);
  assert.deepStrictEqual(pushDirs("git log --grep=push", OTHER_REPO), []);
});

test("pushDirs follows cd and git -C", () => {
  assert.deepStrictEqual(pushDirs("git push", OTHER_REPO), [OTHER_REPO]);
  assert.deepStrictEqual(pushDirs(`cd "${WORKFLOW_ROOT}" && git push`, OTHER_REPO), [WORKFLOW_ROOT]);
  assert.deepStrictEqual(pushDirs(`git -C "${WORKFLOW_ROOT}" push origin HEAD`, OTHER_REPO), [WORKFLOW_ROOT]);
});

test("workflowRoot recognises only the workflow clone", () => {
  assert.strictEqual(workflowRoot(OTHER_REPO), null);
  assert.strictEqual(workflowRoot(path.join(WORKFLOW_ROOT, "scripts")), WORKFLOW_ROOT);
});

test("allows a push from another repo without running the assert (Claude)", () => {
  const started = Date.now();
  const out = runHook({
    tool_input: { command: "git push origin HEAD" },
    hook_event_name: "PreToolUse",
    cwd: OTHER_REPO,
  });
  assert.strictEqual(out.stdout, "");
  assert.strictEqual(out.status, 0);
  assert.ok(Date.now() - started < 5000, "should not have spawned the PowerShell assert");
});

test("allows a push from another repo (Cursor)", () => {
  const out = runHook({ command: "git push", cwd: OTHER_REPO });
  assert.strictEqual(out.json.permission, "allow");
});

test("denies Cursor git push when Assert-AgenticFlow fails or host missing", () => {
  // On CI this tree should pass; we only assert the hook returns JSON.
  const out = runHook({ command: "git push origin HEAD", cwd: WORKFLOW_ROOT }, [], 120000);
  assert.ok(out.json, "expected JSON, got: " + out.stdout);
  assert.ok(
    out.json.permission === "allow" || out.json.permission === "deny",
    "expected allow or deny, got " + out.json.permission
  );
  if (out.json.permission === "deny") {
    assert.ok(/agentic-flow/i.test(out.json.user_message || ""), "deny should mention agentic-flow");
  }
});

fs.rmSync(OTHER_REPO, { recursive: true, force: true });

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
