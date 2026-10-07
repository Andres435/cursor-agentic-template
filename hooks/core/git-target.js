"use strict";

/**
 * Which repo a shell command's git subcommand acts on, and whether that repo is a
 * workflow repo clone. Shared by the push gate and the commit guard; names no IDE.
 */

const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const ASSERT_REL = path.join("scripts", "ticket", "Assert-AgenticFlow.ps1");
const MARKER_REL = path.join(".claude-plugin", "plugin.json");

// Files under plans/ that stay tracked. Every other plans/ file is user-local.
const PLANS_ALLOW = /^plans\/(?:README\.md|closeout-index\.md|workflow-template-plan\.md|examples\/.+)$/;

function unquote(s) {
  const t = String(s || "").trim();
  if ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'"))) {
    return t.slice(1, -1);
  }
  return t;
}

/**
 * Each `git <subcommand>` in the command, with the directory it runs in and its arguments.
 * A git call only counts at the start of a command segment, so `echo "git push"` and prose
 * that mentions git do not match. A leading cd/Set-Location and git -C move the directory.
 */
function gitCalls(command, cwd, subcommand) {
  const calls = [];
  let dir = cwd || process.cwd();
  const segments = String(command || "").split(/&&|\|\||;|\||\r?\n/);
  const sub = new RegExp(
    String.raw`^(?:&\s*)?git(?:\.exe)?((?:\s+(?:-C\s+(?:"[^"]+"|'[^']+'|\S+)|-c\s+\S+|--no-pager))*)\s+` +
      subcommand +
      String.raw`\b(.*)$`,
    "i"
  );
  for (const raw of segments) {
    const seg = raw.trim();
    const cd = seg.match(/^(?:cd|chdir|pushd|sl|Set-Location|Push-Location)(?:\s+-(?:Path|LiteralPath))?\s+(.+)$/i);
    if (cd) {
      dir = path.resolve(dir, unquote(cd[1]));
      continue;
    }
    const m = seg.match(sub);
    if (!m) continue;
    let target = dir;
    const re = /-C\s+("[^"]+"|'[^']+'|\S+)/g;
    let c;
    while ((c = re.exec(m[1] || "")) !== null) target = path.resolve(target, unquote(c[1]));
    calls.push({ dir: target, args: (m[2] || "").trim() });
  }
  return calls;
}

/** The workflow repo clone that contains dir, or null when dir is in any other repo. */
function workflowRoot(dir) {
  if (!dir || !fs.existsSync(dir)) return null;
  const r = spawnSync("git", ["-C", dir, "rev-parse", "--show-toplevel"], {
    encoding: "utf8",
    timeout: 5000,
  });
  if (r.error || r.status !== 0) return null;
  const top = path.resolve(String(r.stdout || "").trim());
  if (!top) return null;
  if (!fs.existsSync(path.join(top, ASSERT_REL))) return null;
  if (!fs.existsSync(path.join(top, MARKER_REL))) return null;
  return top;
}

/** Staged plans/ paths outside the allow-list, relative to the repo root. */
function stagedUserPlans(root) {
  const r = spawnSync("git", ["-C", root, "diff", "--cached", "--name-only", "--diff-filter=ACR", "--", "plans"], {
    encoding: "utf8",
    timeout: 5000,
  });
  if (r.error || r.status !== 0) return [];
  return String(r.stdout || "")
    .split(/\r?\n/)
    .map((s) => s.trim().replace(/\\/g, "/"))
    .filter((s) => s && !PLANS_ALLOW.test(s));
}

module.exports = { gitCalls, workflowRoot, stagedUserPlans, unquote, PLANS_ALLOW, ASSERT_REL };
