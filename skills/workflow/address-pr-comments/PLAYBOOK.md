---
name: address-pr-comments
description: Compact active PR comments into focused context, triage actionable feedback, apply fixes, verify, and prepare follow-up updates.
keywords: PR comments, threads, triage, Fixed, WontFix
disable-model-invocation: true
---

# Address PR Comments

Find PRs for this ticket, compact active comments, triage, fix, verify.

## Token contract

- Load ticket state via [../ticket-context-load/SKILL.md](../ticket-context-load/SKILL.md)
  (`address-pr-comments` profile — full plan + docSet).
- Dispatch `pr-feedback-fetch` per PR, or reload `.cursor/plans/<ticket>-feedback.md`.
- Do not paste raw review JSON into this chat.

## Input

Ticket id, or a PR URL / `repo PR_NUMBER`.

## Fetch

- `github-issues` / GitHub PRs: `gh api` / `gh pr view --comments` scoped to this ticket's branches.
- ADO overlay: use that adapter if present.
- Persist a compact packet to `.cursor/plans/<ticket>-feedback.md`.

## Triage and fix

- Actionable comments → fix in the resolved repo path.
- Wont-fix → record why; do not argue in the thread until the user approves replies.
- Verify with scoped tests. Do not commit unless the user asks.

## Guardrails

- Read-only on the tracker until the user approves replies / thread status.
- Stay inside `affectedRepos`.
