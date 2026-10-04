#!/usr/bin/env node
"use strict";

/**
 * Smoke tests for hooks/ticket-command-nudge.js
 * Run: node hooks/tests/ticket-command-nudge.test.js
 */
const assert = require("assert");
const { spawnSync } = require("child_process");
const path = require("path");

const HOOK = path.join(__dirname, "..", "..", "adapters", "cursor", "hooks", "ticket-command-nudge.js");

function runHook(inputObj) {
  const result = spawnSync(process.execPath, [HOOK], {
    input: JSON.stringify(inputObj),
    encoding: "utf8",
    timeout: 5000,
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
  return { status: result.status, json, stdout: out };
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

console.log("ticket-command-nudge.js smoke tests");

test("start-ticket tells the agent to leave Plan mode before the build", () => {
  const out = runHook({ prompt: "/start-ticket WI21053 bug" });
  assert.ok(out.json, "expected JSON");
  const text = out.json.additional_context || "";
  assert.match(text, /SwitchMode back to Agent/);
  assert.match(text, /plan mode/i);
});

test("engineering-mode plus start-ticket names the playbook", () => {
  const out = runHook({
    prompt: "/engineering-mode /start-ticket WI21053 bug",
  });
  assert.ok(out.json, "expected JSON");
  const text = out.json.additional_context || "";
  assert.match(text, /skills\/start-ticket\/playbooks\/start-ticket\.md/);
  assert.match(text, /SwitchMode back to Agent/);
  assert.match(text, /ctxPct/);
  assert.match(text, /lane mix/);
  assert.match(text, /still runs inline/);
});

test("engineering-mode alone does not invent a ticket playbook", () => {
  const out = runHook({ prompt: "/engineering-mode" });
  const text = (out.json && out.json.additional_context) || "";
  assert.doesNotMatch(text, /playbooks\/start-ticket\.md/);
});

test("unrelated prompt stays empty", () => {
  const out = runHook({ prompt: "what does this do?" });
  assert.strictEqual(out.stdout, "{}");
});

test("a report that mentions /complete-task mid-text stays empty", () => {
  const out = runHook({
    prompt: "Audit done. The close gate in /complete-task and /review-changes only checks bookkeeping.",
  });
  assert.strictEqual(out.stdout, "{}");
});

test("the word implement in a sentence stays empty", () => {
  const out = runHook({ prompt: "Can you implement the fix we discussed?" });
  assert.strictEqual(out.stdout, "{}");
});

test("/implement at the start still nudges", () => {
  const out = runHook({ prompt: "/implement WI21053" });
  assert.match((out.json && out.json.additional_context) || "", /ticket-context-load/);
});

console.log(passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
