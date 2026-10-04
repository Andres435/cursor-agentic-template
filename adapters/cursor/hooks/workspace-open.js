#!/usr/bin/env node
"use strict";

/**
 * User-level workspaceOpen hook. Returns the live tmo-agentic repo as a
 * Cursor plugin path so rules, skills, commands, and hooks load without
 * the folder being named .cursor. One path only — a ticket junction and
 * the canonical clone are the same tree.
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

function canonicalFromRoot(root) {
  const normalized = path.resolve(root);
  const base = path.basename(normalized);

  if (base.toLowerCase() === "repos") {
    const candidate = path.join(normalized, "tmo-agentic");
    return hasPlugin(candidate) ? path.resolve(candidate) : null;
  }

  if (/^WI\d+$/i.test(base)) {
    const parent = path.basename(path.dirname(normalized));
    if (parent.toLowerCase() === "worktrees") {
      const source = path.dirname(path.dirname(normalized));
      const candidate = path.join(source, "repos", "tmo-agentic");
      if (hasPlugin(candidate)) return path.resolve(candidate);
      const junction = path.join(normalized, "tmo-agentic");
      if (hasPlugin(junction)) return path.resolve(junction);
    }
  }

  if (hasPlugin(normalized)) return normalized;
  return null;
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
