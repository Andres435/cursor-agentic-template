#!/usr/bin/env node
"use strict";

/**
 * User-level workspaceOpen hook. Returns the live workflow folder as a
 * Cursor plugin path so rules, skills, and hooks load when the folder is not
 * named .cursor. A folder named .cursor is skipped: Cursor already loads it.
 * One path only — a ticket junction and the canonical clone are the same tree.
 */

const fs = require("fs");
const path = require("path");

function hasPlugin(dir) {
  try {
    return fs.existsSync(path.join(dir, ".cursor-plugin", "plugin.json"));
  } catch {
    return false;
  }
}

// First child folder (not .cursor) that carries .cursor-plugin/plugin.json.
function pluginChild(dir) {
  let entries = [];
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return null;
  }
  for (const e of entries) {
    if (!e.isDirectory() && !e.isSymbolicLink()) continue;
    if (e.name.toLowerCase() === ".cursor") continue;
    const candidate = path.join(dir, e.name);
    if (hasPlugin(candidate)) return path.resolve(candidate);
  }
  return null;
}

function canonicalFromRoot(root) {
  const normalized = path.resolve(root);
  if (path.basename(normalized).toLowerCase() === ".cursor") return null;
  if (hasPlugin(normalized)) return normalized;

  // A ticket worktree root (<source>/worktrees/<ticket>): prefer the canonical clone.
  if (path.basename(path.dirname(normalized)).toLowerCase() === "worktrees") {
    const canonical = pluginChild(path.join(path.dirname(path.dirname(normalized)), "repos"));
    if (canonical) return canonical;
  }
  return pluginChild(normalized);
}

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});

process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const roots = Array.isArray(input.workspace_roots) ? input.workspace_roots : [];
    const found = [];
    const seen = new Set();
    for (const root of roots) {
      const plugin = canonicalFromRoot(root);
      if (!plugin) continue;
      const key = plugin.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      found.push(plugin);
    }
    if (found.length === 0) {
      process.stdout.write("{}");
      return;
    }
    process.stdout.write(JSON.stringify({ pluginPaths: found }));
  } catch {
    process.stdout.write("{}");
  }
});
