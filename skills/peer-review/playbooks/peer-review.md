---
name: peer-review-skill
description: Peer-review a coworker's Azure DevOps PRs for a work item. Drafts short human inline comments for approval, recommends specific existing comments to thumbs-up, then posts only approved text. Use when the user invokes /peer-review or asks to review a coworker's PR for naming, folder placement, or validity.
keywords: peer review, coworker PR, inline comments, thumbs up, reactions, naming, folder, validity, comment voice, checklist
disable-model-invocation: true
---

# Peer Review

Review **someone else’s** work-item PRs. Draft short human inline comments, recommend specific
existing comments that deserve a thumbs-up, wait for approval, then post only the approved text.
Complements pipeline `pr-merge-review` (which already posts bot Blocker/Major). This command does
**not** use those labels in chat or the tracker.

Not `/review-changes` (your staged/pre-merge diff). Not `/address-pr-comments` (fix comments on
your PR).

Load [../references/comment-voice.md](../references/comment-voice.md) **before** drafting any the tracker text.
Load [../references/checklist.md](../references/checklist.md) before reviewing the diff.
Chat output budget: [../../../_shared/severity-and-output.md](../../../_shared/severity-and-output.md#chat-output-budget).

## Token contract

- Do **not** run [ticket-context-load](../../ticket-context-load/SKILL.md) or `Assert-TicketArtifacts`.
  Coworker tickets usually have no local manifest.
- Parent does not dump PR JSON, thread JSON, or full diffs. Fan out `peer-review-pr` per PR
  ([../../../_shared/subagent-functions.md](../../../_shared/subagent-functions.md)).
- Optional scratch: `workflow/tmp/tickets/WI<n>-peer-review.md` (gitignored). Not a `plans/` artifact.

## Input

Prefer a work item number: `<ticket id>`, `AB#<number>`, or `<number>` when the context is an the tracker
item. Also accept a PR URL or `repo PR_NUMBER` (e.g. `app 12299`). Ask if missing.

## Scope

- Resolve product clones from [../../../profile.json](../../../profile.json) `repos[].name` as
  siblings of this `workflow` folder (`../app`, …). Never `Resolve-TicketRoot.ps1`.
- If a repo is not cloned locally, review via the tracker `repo_file` only.
- Never `git checkout` a coworker branch. Never commit, push, or vote Approve/Wait.
- Never write the work item.

## Workflow

1. **Resolve PRs.** `wit_work_item` `get` with `expand: Relations`. Collect Git Pull Request
   artifact links (`vstfs:///Git/PullRequestId/...` or a pullrequest URL). If none, ask for a PR
   URL/`repo PR_NUMBER`. Do not search every repo.

2. **Load each PR.** `repo_pull_request` `get` with `includeChangedFiles: true` and
   `includeWorkItemRefs: true`. Skip abandoned. If only completed PRs exist, say so and ask before
   continuing.

3. **Existing threads.** `repo_pull_request_thread` `list` (compact). Skip duplicates — same
   file+line, or the same ask already made by Project Collection Build Service, Sonar, or a human.
   Also identify specific substantive comments worth endorsing with a thumbs-up. Recommend a
   thumbs-up only when the comment is correct, relevant to the changed code, and adds useful review
   value. Do not recommend reactions for policy/status messages, generic summaries, automated
   formatting issues, or comments whose validity has not been checked. Name the thread and comment
   ids so the user can react to the exact comment.

4. **Diff without checkout.** In the local clone: `git fetch origin <sourceBranch>` then
   `git diff origin/<target>...<source>` (usually `the profile base branch`). If fetch fails, use the tracker changed
   files + `repo_file` `get_content` at the PR source commit.

5. **Fan-out.** One `peer-review-pr` subagent per PR on the standard tier. Subagent returns proposed comments
   only. Parent merges the draft. Subagents never write the tracker.

6. **Draft in chat, wait.** No the tracker writes. Include any thumbs-up recommendations as advisory items;
   the available the tracker write tool does not apply reactions. See output shape below.

7. **After approval.** For each approved id, `repo_pull_request_thread_write` `action: create`:
   - `repositoryId` + `project` + `pullRequestId`
   - `content` = the **approved** `Comment to post` text (verbatim)
   - `filePath` starting with `/`
   - `rightFileStartLine` when known
   - `status: Active`
   If the line cannot be mapped, post a file-level thread (path, no line) — not a PR-summary
   comment. Report created thread IDs.

Approval replies: `post all` | `post C1 C3` | `skip C2` | edit a comment's text. Never `create` a
thread before explicit approval of that id (or `post all`).

## Output shape

```markdown
## Peer review draft — WI<n>

PRs:
- <repo> #<id> — <source> -> <target> — <url>

### Proposed comments
- **C1** — <repo> #<pr> — `path/File.cs:42`
  - Why: <one line, for the user only; not posted>
  - Comment to post: "<exact the tracker text>"

### Recommended thumbs-up
- **T1** — <repo> #<pr> — thread <thread-id>, comment <comment-id> — `path/File.cs:42`
  - Why: <one line explaining why this specific existing comment is correct and useful>

### Skipped as duplicate
- `path:line` — existing thread <id> already covers this

No the tracker comments will be posted until you approve.
Reply: `post all` | `post C1 C3` | `skip C2` | edit a comment's text.
```

Omit empty sections. Cap **10** proposed comments and **5** thumbs-up recommendations per PR. If
nothing is worth leaving or endorsing, say so — do not invent comments or recommend courtesy
reactions. Thumbs-up items are recommendations for the user to apply manually, not approval ids for
posting comments.

After posting:

```markdown
## Peer review posted — WI<n>
- <repo> #<pr> thread <id> — `path:line`
```

## Safety

- Never `create` a thread before explicit approval of that comment id (or `post all`).
- Never claim to have applied a thumbs-up reaction; the current the tracker write tool does not support
  comment reactions.
- Never check out, commit, or push on a coworker branch.
- Never mark threads Fixed/WontFix (that is `/address-pr-comments`).
- Never paste full PR JSON or full diffs into chat.
- Never put Blocker/Major/Minor/Nit (or “finding”) in posted the tracker text, and do not show those
  labels in the draft.
- Never alter core TMO shared-owner logic; flag it in a human comment if the PR touches it.
