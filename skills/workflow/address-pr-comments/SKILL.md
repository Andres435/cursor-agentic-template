---
name: address-pr-comments
description: Find all Azure DevOps PRs for a work item, compact active PR comments and SonarQube PR feedback into focused context, triage actionable feedback, apply fixes, verify, and prepare follow-up updates.
keywords: PR comments, threads, triage, Fixed, WontFix, Sonar feedback, reply, thread status
disable-model-invocation: true
---

# Address PR Comments

Find every Azure DevOps pull request associated with a work item, compact the active PR comments and SonarQube PR feedback into focused context, and address actionable review feedback with minimal token use.

## Token contract

- **Parent does not fetch threads.** Dispatch `pr-feedback-fetch` (Composer) per PR, or reload
  `.cursor/plans/WI<number>-feedback.md` if it already exists and the user did not ask to refresh.
- Fetch protocol lives in [../../../_shared/pr-feedback-fetch.md](../../../_shared/pr-feedback-fetch.md) — load
  that in the subagent only.
- Do not paste raw ADO/Sonar JSON into this chat.

## Input

Prefer a work item number:

- `WI<number>`, for example `WI18345`
- `AB#<number>`, for example `AB#18345`
- `<number>`, for example `18345`, when the user context clearly refers to an ADO work item

Also accept a single PR target when the user wants to scope narrowly:

- A full Azure DevOps pull request URL
- `repo PR_NUMBER`, for example `app 42`

If the work item, repository, or PR number is missing or ambiguous, ask the user for it before continuing.

## Workflow

0. **Load ticket state**
   - Run [../ticket-context-load/SKILL.md](../ticket-context-load/SKILL.md). It roots
     this chat at the worktree and loads the manifest, approved plan, and `docSet` instead of
     re-deriving scope. Skip its plan/implement-artifact expectations if this ticket has no active
     implementation chat pending — PR feedback can arrive after `/complete-task` too — but still root
     at the worktree and load the manifest.

1. **Load or fetch compact feedback**
   - If `.cursor/plans/WI<number>-feedback.md` exists and the user did not ask to refresh, **reload it**.
   - Otherwise dispatch `pr-feedback-fetch` (see [../../../_shared/subagent-functions.md](../../../_shared/subagent-functions.md)
     and [../../../_shared/pr-feedback-fetch.md](../../../_shared/pr-feedback-fetch.md)) once per PR, merge packets,
     persist `WI<number>-feedback.md`. Parent does not call thread `list` / Sonar `issues`.
   - Ask for PR IDs only when relations and the user prompt cannot identify the PR set.

2. **Prepare local branches**
   - Match local repos to the packet. `git status` before switching. Do not discard user changes.
   - If the current branch is not the PR source branch, ask before switching when there are local changes.

3. **Triage** (from the packet, not raw JSON)
   - Classify each PR thread and Sonar finding:
     - **Fix now** -- clear code/test/doc change within scope
     - **Needs clarification** -- ambiguous request or product decision
     - **Out of scope** -- unrelated to the PR/ticket
     - **Already addressed** -- current branch already satisfies the comment
     - **Metric follow-up** -- coverage/duplication gate needs tests/refactor but requires deciding the smallest scoped change
   - If any comment conflicts with the ticket scope, architecture, security, database behavior, or core TMO C-Class logic, pause and ask the user before changing code.
   - If Sonar reports issues in files not changed by the PR, report them but do not fix unless the user asks.
   - Do not address unrelated drive-by refactors unless the user explicitly approves.

4. **Implement fixes**
   - Apply the smallest focused change for each **Fix now** PR thread or Sonar issue.
   - For coverage failures, add focused tests for changed behavior rather than broad low-value tests.
   - For duplication failures, refactor only duplicated code introduced or changed by the PR.
   - Preserve repository patterns and existing abstractions.
   - Add or update tests when the comment changes behavior or protects a regression.
   - Keep unrelated unstaged/untracked files out of the change set.

5. **Verify**
   - Run scoped tests for touched areas only, following [../../../_shared/test-verification.md](../../../_shared/test-verification.md).
   - Run lints/diagnostics for edited files when available.
   - If the project has SonarQube configured, query for existing issues in touched files per `_shared/sonar-verification.md`.
   - If coverage or duplication was changed, run the nearest local coverage/Sonar task when feasible:
     - See your project's SonarQube setup docs if available.
   - Report when local Sonar analysis cannot run because `SONAR_TOKEN`, `Azure_DevOps_PAT`, `pwsh`, SDK, or restore prerequisites are missing.
   - If verification cannot run, report why and do not broaden to full solution tests unless the user explicitly asks.

6. **Review the result**
   - Run `git status`.
   - Show changed files and summarize each addressed PR thread and Sonar finding.
   - Run a focused self-review of the diff before asking for push/resolve approval.

7. **Approval before writes outside the working tree**
   - Do not commit, push, update PR thread status, write ADO comments, or move ADO state without explicit user approval.
   - Before asking for approval, prepare an **ADO PR thread update plan** for every active actionable thread:
     - `Fixed` -- for threads whose request was implemented, verified, or already satisfied by the current branch.
     - `WontFix` -- for threads that will not be changed because they are out of scope, intentionally deferred, duplicate another resolved thread, blocked by missing information, or not technically appropriate.
     - `Active` / no status change -- for threads that need user clarification or cannot be resolved yet.
   - Every proposed `Fixed` or `WontFix` thread update must include the exact reply text that will be posted to that thread. For `WontFix`, the reply must explain why the change is not being made and, when useful, where follow-up should happen.
   - The user must see every proposed ADO PR reply **before** approving. Group replies by proposed status so approval can be given based on each comment's resolution status:
     - `Will mark Fixed`
     - `Will mark WontFix`
     - `Will leave Active / Needs clarification`
   - Present an approval package containing:
     - work item link
     - PR links by repository
     - addressed thread IDs and summaries
     - addressed Sonar issue keys and metric findings
     - unresolved/clarification thread IDs
     - unresolved Sonar gate/coverage/duplication findings
     - tests and checks run
     - files changed
     - proposed commit message
     - ADO PR thread update plan showing each thread ID, proposed status (`Fixed`, `WontFix`, or leave active), and exact reply text when a reply will be posted
   - Wait for the user to approve.

8. **After approval**
   - Commit and push only the reviewed PR-comment fixes.
   - For each approved thread update:
     - Post the approved reply text with `repo_pull_request_thread_write` (action `reply`).
     - Then update the thread status with `repo_pull_request_thread_write` (action `update_status`).
   - Mark addressed active threads as `Fixed`.
   - Mark intentionally unresolved active threads as `WontFix` only after posting the approved explanation.
   - Do not mark Sonar issues fixed manually; push changes and let the next CI/SonarCloud scan update issue and gate status.
   - Post a final summary with PR links, commit hashes, fixed thread IDs, WontFix thread IDs and reasons, addressed Sonar issue keys, unresolved Sonar findings, and verification results.

## Output Shape

When comments are first fetched, produce a compact context packet first:

```markdown
## PR Comment Triage

Work item: WI<number>

PRs:
- <repo> #<number> -- <source> -> <target>

### Fix Now
- <repo> #<pr> thread <id> -- `<file/path>`:<line> -- <latestAsk>

### Needs Clarification
- <repo> #<pr> thread <id> -- <question>

### Already Addressed / Out Of Scope
- <repo> #<pr> thread <id> -- <reason>

### Fixed / Closed Context
- <repo> #<pr> thread <id> -- `<file/path>`:<line> -- done/closed: <one sentence>

### SonarQube Gate / Metrics
- <repo> #<pr> -- gate: <OK/ERROR/unknown> -- coverage: <new/current> -- duplication: <new/current>

### SonarQube Issues
- <repo> #<pr> issue <key> -- `<file/path>`:<line> -- <rule/severity> -- <message>

### Compact Context For Follow-Up
```text
WI<number> PR + Sonar feedback:
<repo> #<pr>
- thread <id> | <status> | <file>:<line/span> | <author> | ask: <one sentence> | context: <symbols/files to read>
- thread <id> | Fixed/Closed | <file>:<line/span> | doneWhere: <file/symbol/commit context>
- thread <id>, <id> | duplicate ask: <one sentence> | context: <symbols/files to read>
- sonar gate | <OK/ERROR/unknown> | coverage <value> | duplication <value>
- sonar issue <key> | <rule> | <severity/impact> | <file>:<line> | ask: <one-sentence fix intent> | context: <symbols/files to read>
- sonar metric | <coverage/duplication> | current <value> | threshold <value if known> | ask: <tests/refactor needed>
```
```

After implementing fixes:

```markdown
## PR Comment Fix Summary

Work item: WI<number>

PRs:
- <repo> #<number>

Addressed:
- <repo> #<pr> thread <id> -- <what changed>
- <repo> #<pr> sonar issue <key> -- <what changed>
- <repo> #<pr> sonar metric <coverage/duplication> -- <tests/refactor added>

Unresolved:
- <repo> #<pr> thread <id> -- <why still open>
- <repo> #<pr> sonar <issue/metric> -- <why still open>

Verification:
- <command/check>: <result>

Approval needed:
- Commit/push: yes/no
- ADO PR thread updates:
  - Will mark Fixed:
    - <repo> #<pr> thread <id> -- reply: "<exact reply to post>"
  - Will mark WontFix:
    - <repo> #<pr> thread <id> -- reply: "<exact rationale to post>"
  - Will leave Active / Needs clarification:
    - <repo> #<pr> thread <id> -- reason: "<why no ADO status update will be made>"
- Sonar re-scan: push required; CI/SonarCloud updates gate after analysis
```

## Safety Rules

- Never mark a thread `Fixed` just because it was read.
- Never mark a thread `Fixed` just because code changed; the approval package must show the exact reply and status first.
- Never close or mark `WontFix` without explicit user approval and an approved explanatory reply.
- Never mark unresolved active review feedback `Fixed`; use `WontFix` with rationale after approval.
- Never commit unrelated local changes.
- Never fetch or print full PR thread JSON unless a specific thread requires it.
- Never search all repositories for PRs when work item relations or user input can identify the PR set.
- Never guess a SonarCloud project key.
- Never mark Sonar issues fixed manually to hide findings; fix locally and let CI/SonarCloud re-scan.
- Never treat coverage or duplication metrics as resolved until tests/refactors are pushed and a new Sonar analysis confirms the gate.
- Never alter core TMO C-Class logic without user approval.
- Never write root cause, QA notes, or dev hours to PR comments; those belong on the work item during PR preparation/closeout.
