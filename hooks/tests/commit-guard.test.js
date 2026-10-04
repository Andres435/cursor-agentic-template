#!/usr/bin/env node
"use strict";

/**
 * Tests for hooks/core/commit-guard.js and the git pre-commit hook.
 * Run: node hooks/tests/commit-guard.test.js
 */
const assert = require("assert");
const { spawnSync } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const { decide } = require("../core/commit-guard.js");
const PRE_COMMIT = path.join(__dirname, "..", "git-hooks", "pre-commit");

function git(dir, args) {
  const r = spawnSync("git", ["-C", dir].concat(args), { encoding: "utf8" });
  if (r.status !== 0) throw new Error("git " + args.join(" ") + ": " + r.stderr);
  return r.stdout;
}

function write(dir, rel, text) {
  const p = path.join(dir, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, text || "x\n");
}

// A fake tmo-agentic clone (the two marker files) and an unrelated product repo.
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), "commit-guard-"));
const WORKFLOW = path.join(TMP, "tmo-agentic");
const PRODUCT = path.join(TMP, "TmoPro");
for (const dir of [WORKFLOW, PRODUCT]) {
  fs.mkdirSync(dir, { recursive: true });
  git(dir, ["init", "-q"]);
}
write(WORKFLOW, "scripts/ticket/Assert-AgenticFlow.ps1", "# marker\n");
write(WORKFLOW, ".claude-plugin/plugin.json", "{}\n");

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

console.log("commit-guard tests");

test("denies git add -f of a ticket file in the workflow clone", () => {
  const d = decide({ command: "git add -f plans/WI12345-manifest.json", cwd: WORKFLOW });
  assert.strictEqual(d.action, "deny");
  assert.match(d.reason, /user-local/);
});

test("denies git add --force plans in the workflow clone", () => {
  assert.strictEqual(decide({ command: "git add --force plans", cwd: WORKFLOW }).action, "deny");
});

test("allows git add -f of a plans/ path in another repo", () => {
  assert.strictEqual(decide({ command: "git add -f plans/x.md", cwd: PRODUCT }).action, "allow");
});

test("allows a plain git add of an example", () => {
  assert.strictEqual(decide({ command: "git add plans/examples/WI00000-manifest.json", cwd: WORKFLOW }).action, "allow");
});

test("does not ask for a work item on a workflow-repo commit", () => {
  assert.strictEqual(decide({ command: 'git commit -m "Fix the gate"', cwd: WORKFLOW }).action, "allow");
});

test("asks for a work item on a product-repo commit", () => {
  const d = decide({ command: 'git commit -m "fix the thing"', cwd: PRODUCT });
  assert.strictEqual(d.action, "ask");
  assert.match(d.reason, /work-item id/);
});

test("allows a product-repo commit that names a work item", () => {
  assert.strictEqual(decide({ command: 'git commit -m "fix: thing [WI21952]"', cwd: PRODUCT }).action, "allow");
});

test("echo of git commit is not a commit", () => {
  assert.strictEqual(decide({ command: 'echo "git commit -m x"', cwd: PRODUCT }).action, "allow");
});

test("denies a commit while a ticket file is staged, and pre-commit agrees", () => {
  write(WORKFLOW, "plans/WI12345-manifest.json", "{}\n");
  git(WORKFLOW, ["add", "-f", "plans/WI12345-manifest.json"]);
  const d = decide({ command: 'git commit -m "x"', cwd: WORKFLOW });
  assert.strictEqual(d.action, "deny");
  assert.match(d.reason, /WI12345-manifest\.json/);
  const hook = spawnSync(process.execPath, [PRE_COMMIT], { cwd: WORKFLOW, encoding: "utf8" });
  assert.strictEqual(hook.status, 1, "pre-commit should refuse");
  git(WORKFLOW, ["rm", "-q", "--cached", "plans/WI12345-manifest.json"]);
});

test("allows a commit that stages only an example, and pre-commit agrees", () => {
  write(WORKFLOW, "plans/examples/WI00000-bug-plan.md", "# example\n");
  git(WORKFLOW, ["add", "plans/examples/WI00000-bug-plan.md"]);
  assert.strictEqual(decide({ command: 'git commit -m "x"', cwd: WORKFLOW }).action, "allow");
  const hook = spawnSync(process.execPath, [PRE_COMMIT], { cwd: WORKFLOW, encoding: "utf8" });
  assert.strictEqual(hook.status, 0, "pre-commit should allow: " + hook.stderr);
});

fs.rmSync(TMP, { recursive: true, force: true });

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
