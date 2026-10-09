---
name: runtime-verify
description: Token rails for local stack recycle and UI verify. Load from start-stack failure handling, the UI steps in skills/start-ticket/references/bug-fix.md and feature-plan.md, and frontend specialists. Do not use as always-on.
keywords: token rails, stack recycle, UI verify, retry policy, no polling, browser CDP, frontend close gate, stack smoke, local login
---

# Runtime verify (token rails)

Humans: [../USER-MANUAL.md](../USER-MANUAL.md). Agents: obey this slice; do not invent a debug loop.

## Ticket system

- Fetch the ticket at most **twice** per `/start-ticket` (one timeout retry).
- Map minimal fields (title, type, state, area, priority) onto `manifest.ticket`. Do **not** persist
  a full ticket JSON file. Later chats read `manifest.ticket`; re-fetch only on "refresh", required-field
  gates, or `/prep-pr` write-back. No batch fetch, no backlog search, no polling.
- If both fetches fail: stop and tell the user to re-authenticate with the tracker, then re-run
  `/start-ticket`.

## Stack (local dev server)

- Start/stop/swap **only** via `scripts/runtime/Start-TicketStack.ps1`, `Stop-TicketStack.ps1` and
  `Swap-TicketStack.ps1`; they read `profile.stacks.services`.
- On start failure whose message is port-in-use or another ticket owning the stack:
  1. Run `scripts/runtime/Stop-TicketStack.ps1 -Force`.
  2. Run the **same** start command **once**.
  3. If it still fails: **stop**. Quote `[FAIL]` / `[SKIP]` lines. Do not diagnose.
- **Forbidden:** probing ports or processes, attaching to server processes, rebuilding to free a
  port, reading environment cards, or exploring server config unless the user opened a **new** debug
  chat and asked for that.
- Missing dependencies, certs, or packages: the launcher self-heals. If it `[SKIP]`s, the user
  fixes the machine — the agent does not start a rebuild loop.

## UI / CSS

- **Frontend layer:** an affected repo with profile layer `frontend` must be exercised before close.
  One happy-path pass, four failed actions then stop. Stamp `Set-StackSmoke.ps1 -Status passed|failed`
  only after the user says which. Close fails without a current `passed` stamp. Do not stamp from
  the agent's own judgment.
- **Otherwise:** human hard-refresh. Do not open the browser unsolicited. After `/start-stack`
  prints URLs, one suggestion line. Do not start browser automation in that turn. A pass the user
  asks for uses the same cap and the same user-confirmed stamp.
- **Local login:** read `local-test-login.local.json` at the workflow root (copy from
  [../local-test-login.example.json](../local-test-login.example.json); gitignored). Use
  `login.username` / `login.password` on the login form. Never commit the file or echo the password
  in chat or logs.
- Markup/CSS-only: one style edit, then ask the user to hard-refresh. Optional: user pastes a
  screenshot for a second edit. Then stop. Do **not** rebuild the stack for markup-only changes;
  rebuild is for compile failures only.
- Prefer a page-scoped style (or the sibling component's existing rule) over a shared stylesheet
  for one-off chrome.

## Stack smoke (optional, never a gate)

After a browser pass or when the user says they tested, **ask once** whether smoke testing passed.
Stamp `scripts/ticket/Set-StackSmoke.ps1 -Ticket <ticket> -Status passed|failed` **only after they
approve**; never from the agent's own judgment. Review and closeout read it with
`scripts/ticket/Get-StackSmoke.ps1` to cite "Tested" vs "untested latest changes". It never blocks a merge
or the close gate. Do not invent a fake-data harness to produce a pass.

## General guardrail

Each rail above has a hard stop. When that stop is reached, report what was observed and what the
next manual step is. Do not substitute your own debugging heuristic.
