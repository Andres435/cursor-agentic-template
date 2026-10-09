#!/usr/bin/env node
"use strict";

/**
 * Every matcher in the Cursor hooks.json compiles and fires on the commands its hook guards.
 * A JSON "\b" is a backspace, not a regex word boundary, so a matcher can parse and still
 * never match; this catches that.
 * Run: node hooks/tests/hooks-manifest.test.js
 */
const assert = require("assert");
const fs = require("fs");
const path = require("path");

const MANIFEST = path.join(__dirname, "..", "..", "hooks.json");
const hooks = JSON.parse(fs.readFileSync(MANIFEST, "utf8")).hooks;

// hook script -> inputs its matcher must accept (and one it must not, where useful).
const EXPECT = {
  "git-commit-ticket.js": { hit: ['git commit -m "x"', "git add -A"], miss: ["git status"] },
  "git-push-agentic-flow.js": { hit: ["git push origin HEAD"], miss: ["git pull"] },
  "script-path-guard.js": { hit: ["pwsh -File C:\\Temp\\x.ps1", "python3 run.py"], miss: ["npm test"] },
};

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

console.log("hooks.json manifest tests");

for (const [event, entries] of Object.entries(hooks)) {
  for (const entry of entries) {
    if (!entry.matcher) continue;
    const script = path.basename(String(entry.command).split(/\s+/).pop());
    test(event + " " + script + ": matcher compiles with no control characters", () => {
      assert.ok(!/[\x00-\x1f]/.test(entry.matcher), "control character in " + JSON.stringify(entry.matcher));
      new RegExp(entry.matcher);
    });
    const want = EXPECT[script];
    if (!want) continue;
    test(event + " " + script + ": matcher fires on what it guards", () => {
      const re = new RegExp(entry.matcher);
      for (const s of want.hit) assert.ok(re.test(s), "should match: " + s);
      for (const s of want.miss || []) assert.ok(!re.test(s), "should not match: " + s);
    });
  }
}

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
