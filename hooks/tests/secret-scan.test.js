#!/usr/bin/env node
"use strict";

/**
 * Tests for hooks/core/secret-scan.js, its use in commit-guard.js and the git pre-commit hook.
 * Fake tokens are assembled at runtime so no literal one is ever committed to this repo.
 * Run: node hooks/tests/secret-scan.test.js
 */
const assert = require("assert");
const { spawnSync } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const { loadPatterns, addedLines, scanLines, ALLOW } = require("../core/secret-scan.js");
const { decide } = require("../core/commit-guard.js");
const PRE_COMMIT = path.join(__dirname, "..", "git-hooks", "pre-commit");

const FAKE = {
  github: "gh" + "p_" + "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8S9",
  anthropic: "sk-" + "ant-" + "api03-" + "x".repeat(40),
  aws: "AK" + "IA" + "ABCDEFGHIJKLMNOP",
  privateKey: "-----BEGIN " + "RSA PRIVATE KEY-----",
  ado: "a".repeat(76) + "AZ" + "DO" + "b1c2",
};

function git(dir, args) {
  const r = spawnSync("git", ["-C", dir].concat(args), { encoding: "utf8" });
  if (r.status !== 0) throw new Error("git " + args.join(" ") + ": " + r.stderr);
  return r.stdout;
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

const TMP = fs.mkdtempSync(path.join(os.tmpdir(), "secret-scan-"));
const REPO = path.join(TMP, "Product");
fs.mkdirSync(REPO, { recursive: true });
git(REPO, ["init", "-q"]);
git(REPO, ["config", "user.email", "t@example.invalid"]);
git(REPO, ["config", "user.name", "t"]);
fs.writeFileSync(path.join(REPO, "README.md"), "hello\n");
git(REPO, ["add", "README.md"]);
git(REPO, ["commit", "-q", "-m", "init"]);

console.log("secret-scan tests");

test("loads only token patterns, and every one compiles", () => {
  const pats = loadPatterns();
  assert.ok(pats.length >= 8, "expected the token set, got " + pats.length);
  assert.ok(!pats.some((p) => p.name === "nuget-cleartext-password"), "heuristic patterns stay out of commits");
});

test("each fake token is caught by its own pattern", () => {
  const names = scanLines(Object.values(FAKE).map((text) => ({ file: "f.txt", text }))).map((h) => h.pattern);
  for (const want of ["github-token", "anthropic-api-key", "aws-access-key", "private-key", "azure-devops-pat"]) {
    assert.ok(names.includes(want), want + " not caught: " + names.join(", "));
  }
});

test("ordinary code and the heuristic words pass", () => {
  const lines = [
    "const password = process.env.DB_PASSWORD;",
    "Writes Username/ClearTextPassword into NuGet.Config",
    "sha256 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  ].map((text) => ({ file: "a.js", text }));
  assert.deepStrictEqual(scanLines(lines), []);
});

test("the allow marker exempts a line", () => {
  assert.deepStrictEqual(scanLines([{ file: "a", text: FAKE.github + " // " + ALLOW }]), []);
});

test("addedLines reads only + lines and the new file name", () => {
  const diff = ["diff --git a/x b/x", "--- a/x", "+++ b/x", "@@ -1 +1 @@", "-old " + FAKE.aws, "+new"].join("\n");
  assert.deepStrictEqual(addedLines(diff), [{ file: "x", text: "new" }]);
});

test("findings name file and pattern, never the token", () => {
  fs.writeFileSync(path.join(REPO, "config.js"), "const k = '" + FAKE.github + "';\n");
  git(REPO, ["add", "config.js"]);
  const d = decide({ command: 'git commit -m "WI12345 add config"', cwd: REPO });
  assert.strictEqual(d.action, "deny");
  assert.match(d.reason, /config\.js \(github-token\)/);
  assert.ok(!d.reason.includes(FAKE.github), "reason must not echo the secret");
});

test("git pre-commit refuses the same staged secret", () => {
  const hook = spawnSync(process.execPath, [PRE_COMMIT], { cwd: REPO, encoding: "utf8" });
  assert.strictEqual(hook.status, 1, "pre-commit should block");
  assert.match(hook.stderr, /secret-shaped content/);
  git(REPO, ["rm", "-q", "--cached", "config.js"]);
  fs.rmSync(path.join(REPO, "config.js"));
});

test("git add && git commit in one command scans the unstaged edit", () => {
  fs.writeFileSync(path.join(REPO, "README.md"), "hello\n" + FAKE.aws + "\n");
  const d = decide({ command: 'git add README.md && git commit -m "WI12345 x"', cwd: REPO });
  assert.strictEqual(d.action, "deny");
  git(REPO, ["checkout", "--", "README.md"]);
});

test("a clean commit is allowed", () => {
  fs.writeFileSync(path.join(REPO, "ok.js"), "module.exports = 1;\n");
  git(REPO, ["add", "ok.js"]);
  // No secret: not denied (it may still ask for a ticket id, per the profile's prefix).
  assert.notStrictEqual(decide({ command: 'git commit -m "WI12345 ok"', cwd: REPO }).action, "deny");
  const hook = spawnSync(process.execPath, [PRE_COMMIT], { cwd: REPO, encoding: "utf8" });
  assert.strictEqual(hook.status, 0, hook.stderr);
});

fs.rmSync(TMP, { recursive: true, force: true });

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
