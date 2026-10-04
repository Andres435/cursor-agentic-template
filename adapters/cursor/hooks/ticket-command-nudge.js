#!/usr/bin/env node
"use strict";

// Cursor beforeSubmitPrompt hook. Logic lives in ../../../hooks/core/ticket-nudge.js; this file only
// speaks Cursor's contract (prompt on stdin, { additional_context } on stdout).

const { nudgesFor } = require("../../../hooks/core/ticket-nudge.js");

const CURSOR_VERBS = {
  exitPlan: "SwitchMode back to Agent",
  renameChat:
    "Rename this chat to 'WI##### <phase>' using cursor-app-control rename_chat so the user can navigate multiple open tabs.",
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
    const bits = nudgesFor(prompt, CURSOR_VERBS);
    process.stdout.write(bits.length ? JSON.stringify({ additional_context: bits.join(" ") }) : "{}");
  } catch (_err) {
    process.stdout.write("{}");
  }
});
