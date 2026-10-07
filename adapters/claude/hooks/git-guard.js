#!/usr/bin/env node
"use strict";

// Claude Code PreToolUse hook (matcher: Bash|PowerShell): the commit guard and the push gate
// in one node process. Two hook entries meant two node starts (about 240 ms) on every shell
// call, git or not. A command with no `git` in it exits at once; otherwise both bridges run
// and the stricter answer wins (deny over ask), as Claude does when two hooks disagree, so
// `git commit -m x && git push` is still push-gated after the commit question.

const commit = require("./git-commit-ticket.js");
const push = require("./git-push-agentic-flow.js");
const { writeHookError } = require("../../../hooks/core/hook-log.js");

const RANK = { deny: 2, ask: 1 };

function decide(input) {
  const command = String(((input && input.tool_input) || {}).command || "");
  if (!/\bgit(\.exe)?\b/i.test(command)) return null;
  const answers = [commit.handle(input), push.handle(input)].filter(Boolean);
  if (!answers.length) return null;
  answers.sort(
    (a, b) => (RANK[b.hookSpecificOutput.permissionDecision] || 0) - (RANK[a.hookSpecificOutput.permissionDecision] || 0)
  );
  return answers[0];
}

module.exports = { decide };

if (require.main === module) {
  let raw = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => {
    raw += chunk;
  });
  process.stdin.on("end", () => {
    let input = {};
    try {
      input = JSON.parse(raw || "{}");
    } catch (err) {
      writeHookError("claude:git-guard", err);
    }
    const out = decide(input);
    if (out) process.stdout.write(JSON.stringify(out));
    process.exit(0);
  });
}
