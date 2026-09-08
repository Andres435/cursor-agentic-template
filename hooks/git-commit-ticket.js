#!/usr/bin/env node
"use strict";

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  try {
    const input = JSON.parse(raw || "{}");
    const command = String(
      input.command || input.command_line || input.cmd || ""
    );
    const cwd = String(
      input.cwd || input.working_directory || process.cwd()
    );

    if (!/\bgit(?:\.exe)?\s+commit\b/i.test(command)) {
      process.stdout.write(JSON.stringify({ permission: "allow" }));
      return;
    }

    const ticketInCommand = /WI\d{4,}/i.test(command);
    const cwdTicket = cwd.match(/WI(\d{4,})/i);
    if (ticketInCommand) {
      process.stdout.write(JSON.stringify({ permission: "allow" }));
      return;
    }

    const suggested = cwdTicket ? "WI" + cwdTicket[1] : "WI#####";
    process.stdout.write(
      JSON.stringify({
        permission: "ask",
        user_message:
          "Commit message has no work-item id. Include " +
          suggested +
          " (example: fix(legacy): describe change [" +
          suggested +
          "]).",
        agent_message:
          "Hook blocked a git commit without a WI ticket ref. Ask the user to include " +
          suggested +
          " in the message (do not commit until they confirm).",
      })
    );
  } catch (_err) {
    process.stdout.write(JSON.stringify({ permission: "allow" }));
  }
});
