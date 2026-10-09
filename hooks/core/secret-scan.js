"use strict";

/**
 * Secret scan for commits. Reads the one pattern list, scripts/ticket/secret-patterns.json,
 * and uses its "token" patterns only: high-confidence key formats (PATs, cloud keys, private
 * keys). The "heuristic" ones (ClearTextPassword, password=) stay in /review-changes staging,
 * because this repo's own docs and scripts name them.
 *
 * Scans ADDED lines only, so a secret already in history never blocks an unrelated edit.
 * A line containing `secret-scan:allow` is exempt. Findings name the file and the pattern,
 * never the matched text.
 */

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const PATTERNS_FILE = path.join(__dirname, "..", "..", "scripts", "ticket", "secret-patterns.json");
const ALLOW = "secret-scan:allow";

function loadPatterns(file) {
  const doc = JSON.parse(fs.readFileSync(file || PATTERNS_FILE, "utf8"));
  return (doc.patterns || [])
    .filter((p) => p.kind === "token")
    .map((p) => ({ name: p.name, re: new RegExp(p.pattern, p.ignoreCase ? "i" : "") }));
}

/** [{file, text}] for each added line in a unified diff (-U0 or wider). */
function addedLines(diff) {
  const out = [];
  let file = null;
  for (const line of String(diff || "").split(/\r?\n/)) {
    if (line.startsWith("+++ ")) {
      const m = line.match(/^\+\+\+ (?:b\/)?(.*)$/);
      file = m && m[1] !== "/dev/null" ? m[1] : null;
    } else if (file && line.startsWith("+")) {
      out.push({ file, text: line.slice(1) });
    }
  }
  return out;
}

/** [{file, pattern}] — one finding per file and pattern. */
function scanLines(lines, patterns) {
  const pats = patterns || loadPatterns();
  const seen = new Set();
  const hits = [];
  for (const { file, text } of lines) {
    if (text.includes(ALLOW)) continue;
    for (const p of pats) {
      if (!p.re.test(text)) continue;
      const key = file + "\0" + p.name;
      if (!seen.has(key)) {
        seen.add(key);
        hits.push({ file, pattern: p.name });
      }
    }
  }
  return hits;
}

function gitDiff(dir, extra) {
  const r = spawnSync("git", ["-C", dir, "diff", "--no-color", "--no-ext-diff", "-U0"].concat(extra), {
    encoding: "utf8",
    timeout: 10000,
    maxBuffer: 64 * 1024 * 1024,
  });
  if (r.error || r.status !== 0) return "";
  return r.stdout;
}

/**
 * Findings in what a commit in `dir` would record: the staged diff, plus unstaged edits to
 * tracked files when `includeWorktree` (git commit -a, or a git add in the same command).
 */
function scanRepo(dir, includeWorktree) {
  let diff = gitDiff(dir, ["--cached"]);
  if (includeWorktree) diff += "\n" + gitDiff(dir, []);
  return scanLines(addedLines(diff));
}

function describe(hits) {
  const list = hits.map((h) => h.file + " (" + h.pattern + ")").join(", ");
  return (
    "Commit blocked: secret-shaped content in " + list + ". Remove it and use an environment variable " +
    "or the user-level config instead. A false positive: add `" + ALLOW + "` to that line."
  );
}

module.exports = { loadPatterns, addedLines, scanLines, scanRepo, describe, ALLOW, PATTERNS_FILE };
