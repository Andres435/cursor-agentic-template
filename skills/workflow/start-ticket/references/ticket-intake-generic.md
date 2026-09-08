---
name: ticket-intake-generic
description: Generic ticket intake for any ticket system. Covers "none" (paste title/AC), "github-issues" (gh CLI fetch), and provides a placeholder for custom systems.
keywords: intake, ticket fetch, github issues, none, ticket system, acceptance criteria
---

# Ticket Intake (Generic)

Load this reference in `/start-ticket` after identifying the `ticketSystem` from `profile.json`.

## Intake by `ticketSystem`

### `none` — paste-based

1. Ask the user to paste the ticket title and acceptance criteria.
2. Assign a local ID using `profile.ticketPrefix` + a sequence number (e.g. `TICKET-42`).
3. No required-field gate — work with what was provided.

### `github-issues` — GitHub Issues

1. Fetch: `gh issue view <number> --json title,body,labels,assignees,milestone`
2. Map fields: `title` → title, `body` → description + AC, `labels` → tags.
3. Required fields gate: title and body must be non-empty. If missing, stop and ask.

### Custom system

Drop a custom intake reference file next to this one (e.g. `jira-intake.md`) and load it instead.
Follow the same pattern: fetch → map → gate.

## Required fields gate (all systems)

Before routing, confirm:
- Title is present and non-trivial.
- Acceptance criteria (or equivalent "done" definition) is present.

If either is missing, ask the user to fill it before proceeding to the ticket router.

## After intake

Pass the fetched fields to the ticket router:
[../../../skills/workflow/ticket-router/SKILL.md](../../../skills/workflow/ticket-router/SKILL.md)
