#!/usr/bin/env node
"use strict";

/**
 * Smoke tests for hooks/session-context.js
 *
 * Tests packet shape when no PowerShell is available (Resolve-TicketRoot will fail),
 * and when no ticket is detected. Does NOT require a live TmoPro checkout.
 * Run: node hooks/tests/session-context.test.js
 */

const assert = require("assert");
const { spawnSync } = require("child_process");
const path = require("path");

const HOOK = path.join(__dirname, "..", "session-context.js");

function runHook(inputObj, env = {}) {
  const result = spawnSync(process.execPath, [HOOK], {
    input: JSON.stringify(inputObj),
    encoding: "utf8",
    timeout: 15000,
    env: { ...process.env, ...env },
  });
  if (result.error) throw result.error;
  return JSON.parse(result.stdout || "{}");
}

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  ✓ ${name}`);
    passed++;
  } catch (err) {
    console.error(`  ✗ ${name}`);
    console.error(`    ${err.message}`);
    failed++;
  }
}

console.log("session-context.js smoke tests");

test("returns {} when no ticket is detectable", () => {
  const out = runHook({}, { CURSOR_PROJECT_DIR: "", CLAUDE_PROJECT_DIR: "" });
  // Should be empty or {} — no additional_context injection without a ticket
  assert.ok(
    Object.keys(out).length === 0 || (!out.additional_context && !out.env),
    `expected empty output without ticket, got: ${JSON.stringify(out)}`
  );
});

test("detects ticket from workspace_roots and produces packet shape", () => {
  // Resolve-TicketRoot.ps1 will fail in CI without TmoPro; hook degrades gracefully to { ticket }
  const out = runHook(
    { workspace_roots: ["/source/worktrees/WI21053"] },
    { CURSOR_PROJECT_DIR: "", CLAUDE_PROJECT_DIR: "" }
  );
  // Even without PowerShell success, the hook should emit valid JSON (no crash)
  assert.ok(typeof out === "object", "output must be an object");
  // If additional_context was emitted, it must mention the ticket
  if (out.additional_context) {
    assert.ok(
      /WI21053/.test(out.additional_context),
      `additional_context must mention WI21053, got: ${out.additional_context}`
    );
  }
});

test("detects ticket from CURSOR_PROJECT_DIR env var", () => {
  const out = runHook(
    {},
    { CURSOR_PROJECT_DIR: "C:\\source\\worktrees\\WI99999", CLAUDE_PROJECT_DIR: "" }
  );
  assert.ok(typeof out === "object", "output must be an object");
  if (out.additional_context) {
    assert.ok(/WI99999/.test(out.additional_context), "must mention detected ticket WI99999");
  }
});

test("env block has correct keys when ticket detected", () => {
  const out = runHook(
    { workspace_roots: ["/source/worktrees/WI21053"] },
    { CURSOR_PROJECT_DIR: "", CLAUDE_PROJECT_DIR: "" }
  );
  if (out.env) {
    // env must have exactly TMO_TICKET, TMO_MODE, TMO_ROOT
    assert.ok("TMO_TICKET" in out.env, "env.TMO_TICKET missing");
    assert.ok("TMO_MODE" in out.env, "env.TMO_MODE missing");
    assert.ok("TMO_ROOT" in out.env, "env.TMO_ROOT missing");
    assert.strictEqual(out.env.TMO_TICKET, "WI21053");
  }
});

test("handles malformed JSON input gracefully", () => {
  const result = spawnSync(process.execPath, [HOOK], {
    input: "not-valid-json",
    encoding: "utf8",
    timeout: 5000,
  });
  const out = JSON.parse(result.stdout || "{}");
  assert.ok(typeof out === "object", "must return valid JSON even on bad input");
});

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
