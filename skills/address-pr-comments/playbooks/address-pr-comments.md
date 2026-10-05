---
name: address-pr-comments
description: Find the PRs for a ticket, compact active PR comments and static-analysis feedback into focused context, triage actionable feedback, apply fixes, verify, and prepare follow-up updates.
keywords: PR comments, threads, triage, Fixed, WontFix, static analysis feedback, reply, thread status, stack smoke
disable-model-invocation: true
---

# Address PR Comments

Find every pull request for a ticket, compact the active comments and static-analysis feedback into
focused context, and address actionable review feedback with minimal token use.

## Token contract

- **Parent does not fetch threads.** `dispatch` `pr-feedback-fetch` (fast tier) per PR, or reload
  `.cursor/plans/<ticket>-feedback.md` if it exists and the user did not ask to refresh
  ([../../../_shared/subagent-functions.md](../../../_shared/subagent-functions.md)).
- Do not paste raw review or analysis JSON into this chat.

## Input

Prefer a ticket id (`profile.ticketPrefix` + number, or a bare number when the context is clear).
Also accept a single PR URL or `repo PR_NUMBER` to scope narrowly. If the ticket, repo, or PR is
missing or ambiguous, ask before continuing.

## Workflow

0. **Load ticket state**
   - Run [../../ticket-context-load/SKILL.md](../../ticket-context-load/SKILL.md) (full plan +
     `docSet`). It roots this chat at the resolved ticket root. PR feedback can arrive after
     `/complete-task`, so skip its implement-artifact expectations if no implementation chat is
     pending — but still root at the resolved path and load the manifest.

1. **Load or fetch compact feedback**
   - Reload `<ticket>-feedback.md` unless the user asked to refresh. Otherwise `dispatch`
     `pr-feedback-fetch` once per PR, merge packets, persist `<ticket>-feedback.md`.
   - Fetch by tracker: `github-issues` → `gh pr view --comments` / `gh api` scoped to this ticket's
     branches; `ado` → that overlay's PR tools; `none` → ask for the PR URLs.
   - Ask for PR IDs only when the ticket's relations and the prompt cannot identify the PR set.

2. **Prepare local branches**
   - Match local repos to the packet. `git status` before switching; do not discard user changes.
     Ask before switching branches when there are local changes.

3. **Triage** (from the packet, not raw JSON). Classify each thread and static-analysis finding:
   - **Fix now** — clear code/test/doc change within scope
   - **Needs clarification** — ambiguous request or product decision
   - **Out of scope** — unrelated to the PR/ticket
   - **Already addressed** — the current branch already satisfies the comment
   - **Metric follow-up** — a coverage/duplication gate needs tests or refactor; decide the smallest scoped change
   - If a comment conflicts with ticket scope, architecture, security, schema behavior, or a shared
     module's contract, pause and ask before changing code. Report findings in files the PR did not
     change; do not fix them unless asked. No unrelated drive-by refactors.

4. **Implement fixes**
   - Smallest focused change per **Fix now** item; preserve repo patterns. Add or update tests when
     the comment changes behavior or protects a regression. For coverage, add focused tests for the
     changed behavior; for duplication, refactor only duplicated code the PR introduced.
   - Keep unrelated unstaged/untracked files out of the change set.
   - If a **Fix now** change altered product logic or runtime behavior (not docs-only, not
     reply-only) and `manifest.stackSmoke` is `passed` or `failed`:
     `.\.cursor\scripts\Set-StackSmoke.ps1 -Ticket <ticket> -Status stale -Notes "<what changed>"`.
     That swaps Tested → Untested latest changes. `/complete-task` also detects this from the
     work-diff fingerprint if the stamp is still `passed`.

5. **Verify**
   - Scoped tests for touched areas only ([../../../_shared/test-verification.md](../../../_shared/test-verification.md));
     lints/diagnostics for edited files; static analysis on touched files when the project has it.
   - If coverage or duplication changed, run the nearest local coverage/analysis task when feasible.
     Report prerequisites that are missing (tokens, SDK, restore) instead of broadening to a full run.

6. **Review the result**
   - `git status`, changed files, a summary per addressed thread/finding, and a focused self-review
     of the diff before asking for push/resolve approval.

7. **Approval before writes outside the working tree**
   - Do not commit, push, update thread status, write tracker comments, or move tracker state
     without explicit approval.
   - Prepare a **thread update plan** for every active actionable thread, grouped by proposed status:
     `Will mark Fixed` (implemented, verified, or already satisfied) · `Will mark WontFix` (out of
     scope, deferred, duplicate, blocked, or not appropriate — the reply says why and where
     follow-up belongs) · `Will leave Active / Needs clarification`.
   - Every proposed `Fixed` / `WontFix` update carries the **exact reply text** to post. The user
     sees every reply before approving.
   - Approval package: ticket link; PR links by repo; addressed thread ids and finding keys;
     unresolved items; checks run; files changed; proposed commit message; the thread update plan.
   - Wait for the user to approve.

8. **After approval**
   - Commit and push only the reviewed fixes. For each approved thread: post the approved reply,
     then set the status. `WontFix` only after the approved explanation is posted.
   - Never mark analysis findings fixed manually; push and let the next CI scan update gate status.
   - Post a final summary: PR links, commit hashes, fixed and WontFix thread ids with reasons,
     unresolved findings, verification results.

## Output Shape

First fetch — a compact packet, headings only when they have content:

```markdown
## PR Comment Triage
Ticket: <ticket>
PRs: <repo> #<number> -- <source> -> <target>

### Fix Now · Needs Clarification · Already Addressed / Out Of Scope
- <repo> #<pr> thread <id> -- `<file>`:<line> -- <latest ask / reason>

### Fixed / Closed Context
- <repo> #<pr> thread <id> -- `<file>`:<line> -- done/closed: <one sentence>

### Static Analysis (gate, metrics, issues)
- <repo> #<pr> -- gate: <ok/error/unknown> -- coverage <v> -- duplication <v>
- <repo> #<pr> issue <key> -- `<file>`:<line> -- <rule/severity> -- <message>
```

After fixes — `## PR Comment Fix Summary`: Addressed · Unresolved · Verification · Approval needed
(commit/push yes/no, plus the grouped thread update plan with exact replies).

## Safety Rules

- Never mark a thread `Fixed` just because it was read or because code changed; the approval
  package shows the exact reply and status first.
- Never close or `WontFix` without explicit approval and an approved explanatory reply. Never mark
  unresolved review feedback `Fixed`.
- Never commit unrelated local changes. Never print full PR thread JSON unless one thread needs it.
- Never search every repo for PRs when relations or user input identify the set.
- Never guess an analysis project key. Never treat coverage/duplication as resolved until a new
  analysis confirms the gate.
- Never alter a shared module's contract without approval.
- Never write root cause, QA notes, or dev hours to PR comments; those belong on the ticket during
  PR preparation/closeout.
