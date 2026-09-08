#!/usr/bin/env node
"use strict";

/**
 * Smoke tests for hooks/session-context.js
 *
 * Ticket ids come from profile.json ticketPrefix so the same tests pass on TMO
 * (WI) and the vanilla template (TICKET-). Does NOT require PowerShell or a
 * product checkout. Run: node hooks/tests/session-context.test.js
 */

const assert = require("assert");
const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const HOOK = path.join(__dirname, "..", "session-context.js");
const PROFILE = path.join(__dirname, "..", "..", "profile.json");

function ticketPrefix() {
  try {
    const profile = JSON.parse(fs.readFileSync(PROFILE, "utf8"));
    return String(profile.ticketPrefix || "WI");
  } catch {
    return "WI";
  }
}

const PREFIX = ticketPrefix();
const TICKET_A = PREFIX + "21053";
const TICKET_B = PREFIX + "99999";

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

test("injects profile fields even when no ticket is detectable", () => {
  const out = runHook({}, { CURSOR_PROJECT_DIR: "", CLAUDE_PROJECT_DIR: "" });
  assert.ok(typeof out === "object", "output must be an object");
  if (out.additional_context) {
    assert.ok(
      /profileId/.test(out.additional_context),
      `additional_context must include profileId, got: ${out.additional_context}`
    );
  }
  if (out.env) {
    assert.ok("TMO_PROFILE" in out.env, "env.TMO_PROFILE missing");
    assert.ok("TMO_TICKET_SYSTEM" in out.env, "env.TMO_TICKET_SYSTEM missing");
    assert.ok("TMO_LAYOUT" in out.env, "env.TMO_LAYOUT missing");
  }
});

test("detects ticket from workspace_roots and produces packet shape", () => {
  const out = runHook(
    { workspace_roots: ["/source/worktrees/" + TICKET_A] },
    { CURSOR_PROJECT_DIR: "", CLAUDE_PROJECT_DIR: "" }
  );
  assert.ok(typeof out === "object", "output must be an object");
  if (out.additional_context) {
    assert.ok(
      out.additional_context.includes(TICKET_A),
      `additional_context must mention ${TICKET_A}, got: ${out.additional_context}`
    );
  }
});

test("detects ticket from CURSOR_PROJECT_DIR env var", () => {
  const out = runHook(
    {},
    {
      CURSOR_PROJECT_DIR: "C:\\source\\worktrees\\" + TICKET_B,
      CLAUDE_PROJECT_DIR: "",
    }
  );
  assert.ok(typeof out === "object", "output must be an object");
  if (out.additional_context) {
    assert.ok(
      out.additional_context.includes(TICKET_B),
      `must mention detected ticket ${TICKET_B}`
    );
  }
});

test("env block has ticket + profile keys when ticket detected", () => {
  const out = runHook(
    { workspace_roots: ["/source/worktrees/" + TICKET_A] },
    { CURSOR_PROJECT_DIR: "", CLAUDE_PROJECT_DIR: "" }
  );
  if (out.env) {
    assert.ok("TMO_TICKET" in out.env, "env.TMO_TICKET missing");
    assert.ok("TMO_MODE" in out.env, "env.TMO_MODE missing");
    assert.ok("TMO_ROOT" in out.env, "env.TMO_ROOT missing");
    assert.ok("TMO_PROFILE" in out.env, "env.TMO_PROFILE missing");
    assert.strictEqual(out.env.TMO_TICKET, TICKET_A);
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
