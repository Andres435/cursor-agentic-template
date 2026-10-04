#!/usr/bin/env node
"use strict";

// Claude Code UserPromptSubmit hook. Logic lives in ../../../hooks/core/ticket-nudge.js; this
// file only speaks Claude's contract (prompt on stdin, hookSpecificOutput.additionalContext
// on stdout). Claude cannot rename chats, so there is no rename hint.

const { nudgesFor } = require("../../../hooks/core/ticket-nudge.js");

const CLAUDE_VERBS = {
  exitPlan: "exit plan mode (ExitPlanMode)",
};

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const prompt = String(input.prompt || input.content || input.text || "");
    const bits = nudgesFor(prompt, CLAUDE_VERBS);
    if (bits.length) {
      process.stdout.write(
        JSON.stringify({
          hookSpecificOutput: {
            hookEventName: "UserPromptSubmit",
            additionalContext: bits.join(" "),
          },
        })
      );
    }
    process.exit(0);
  } catch (_err) {
    process.exit(0);
  }
});
