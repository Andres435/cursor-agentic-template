---
name: runtime-verify
description: Token rails for local stack recycle and UI verify. Load from start-stack failure handling, bug-fix/feature-plan UI steps. Do not use as always-on.
keywords: token rails, stack recycle, UI verify, retry policy, no polling, start-stack
---

# Runtime verify (token rails)

Agents: obey this slice; do not invent a debug loop.

## Ticket system

- Fetch the ticket at most **twice** per `/start-ticket` (one timeout retry).
- Map minimal fields (title, type, state, priority) onto `manifest.ticket`. Do **not** persist a
  full ticket JSON file. Later chats read `manifest.ticket`; re-fetch only on "refresh", required-field
  gates, or `/prep-pr` write-back. No batch fetch, no backlog search, no polling.
- If both fetches fail: stop and tell the user to re-authenticate, then re-run `/start-ticket`.

## Stack (local dev server)

- Start/stop **only** via the script declared in `profile.stacks.startCommand`.
- On start failure: stop the current process, retry **once** with the same command.
- If it still fails: **stop**. Quote any `[FAIL]` / `[SKIP]` lines. Do not diagnose ports, processes,
  or config unless the user opens a **new** debug chat and asks for that.
- Launcher self-heals missing deps. If it skips, the user fixes the machine — the agent does not
  start a rebuild loop.

## UI verification

- At most **one** browser screenshot per UI check step. Describe what you see; do not loop.
- Forbidden: polling a page, repeated screenshots for the same check, opening DevTools to diagnose
  unless the user asks.

## General guardrail

Each rail above has a hard stop. When that stop is reached, report what was observed and what the
next manual step is. Do not substitute your own debugging heuristic.
