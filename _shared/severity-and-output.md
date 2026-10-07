---
name: severity-and-output
description: Workspace standard for review severity labels, finding format, report shape, verdicts, and how long each command's chat output may be.
keywords: severity, blocker, major, minor, nit, output format, findings, verdict, chat output budget, compact, token-class, instruction tokens, tool-result, Ctx%
---

# Severity and output spec (workspace standard)

Used by every reviewer / planner artifact in the workspace. Every consumer must reference this file rather than redefining these rules.

## Chat output budget

Long output is a real cost, not a style preference: it is emitted tokens, and it buries the one line
the user needs. These are caps per command, not targets to fill.

| Command / step | Chat output |
|---|---|
| `ticket-router` | one line: work type, mode, repos, integration, specialists |
| `ticket-context-load` | one `Loaded <ticket> — …` line |
| `/start-ticket` **branch** | startup line · implementation summary · "run `/review-changes` in a new chat, then `/complete-task`" |
| `/start-ticket` **worktree** | startup line · approved Work Plan with `[low]/[med]/[high]` tags · handoff paste block last |
| plan revision in plan mode | **only the section that changed** — never reprint the whole plan |
| `/implement` progress | `step N/M done`; do not narrate file reads |
| `/implement` stop-for-review | steps done · files changed per repo · tests + outcome · Deviations · what was left out |
| `/complete-task` approval package | the package fields only, no commentary; do **not** reload the Work Plan steps or `docSet` |
| `/peer-review` draft | proposed comments only (id, path:line, Why, Comment to post); no diffs/JSON; no Blocker/Major labels |
| retrospective | ≤5 lines (`skills/complete-task/references/task-retrospective.md`) |
| any subagent return | the compact packet shape in [subagent-functions.md](subagent-functions.md) |

Always, in every command:

- **Never dump** a manifest, plan file, work item, raw JSON packet, full diff, or whole file.
- Never end with only a path pointer where the user needed the content (a plan, a verdict, a summary).
- Omit empty sections entirely — no "N/A", no "no issues found", no strengths-only paragraphs.
- State what you did not do, once, plainly. Do not re-explain it.

Commands must not restate these rules in their own words — link this section instead. When a command
appears to contradict it, this file wins.

## Severity labels

| Level | Meaning |
|-------|---------|
| **Blocker** | Must fix before merge |
| **Major** | Strong recommendation before merge |
| **Minor** | Improvement |
| **Nit** | Style / readability only |

## Output discipline

- Every actionable finding starts with a repo-relative `` `path/File.cs:42` `` in backticks -- one anchor line per issue. Use a range only when needed (e.g. `Services/Loan.cs:120-135`).
- If the exact line cannot be determined from the diff, keep the path in backticks and append `(line unknown; search: SymbolOrKeyword)` -- do not omit the file.
- One line per finding where possible. Pattern: `` `path/File.cs:10` `` -- **Blocker** -- short description (same shape for Major / Minor / Nit). No paragraph essays per item.
- Default depth: report **Blocker** and **Major**. Include **Minor** / **Nit** only when the user asks for full detail or the item is a quick fix that affects correctness or consistency.
- Caps (default): at most **5** Blockers listed individually, then "+N more Blockers"; at most **8** Majors, then "+N more"; Minors / Nits cap at **10** combined or summarized in one short line unless exhaustive detail is requested.
- Omit any section with no actionable content. Do not write "N/A", "no issues", "no significant concerns", strengths-only paragraphs, or informational-only prose; leave the whole section out.
- Do not paste full diffs or entire files.
- Do not repeat the same issue under multiple headings.
- Verdict line is always present. Findings appears only when there is at least one actionable item.

## Standard report shape

Use these headings only when they have content. The verdict (and Confidence Score, see [confidence-score.md](../skills/complete-task/references/confidence-score.md)) are always included.

```markdown
## Review report

### Branch (or scope)

<branch / ref / description of what was reviewed>

### Files changed

<count> (Added / Modified / Deleted / Renamed)

### Modules touched

<short list>

### Findings

- `repo/path/File.cs:42` -- **Blocker** -- short description
- `repo/path/Other.cs:10` -- **Major** -- short description

### Notes

<Optional. Max 2-3 short lines: API breaks, residual risk, test expectation churn, stack smoke label when UI/runtime. Omit if empty.>

### Confidence Score

<Multi-dimensional block per skills/complete-task/references/confidence-score.md>

### Verdict

**Ready** | **Ready with fixes** | **Not ready** -- one-line rationale.
```

### Verdict rules

The findings decide the verdict, not the reviewer's mood. Any **Blocker** → **Not ready**. Any
**Major** → **Ready with fixes** (or Not ready). Only Minor/Nit → **Ready** or Ready with fixes.
`Set-ReviewReady.ps1` refuses a stamp that breaks this, and close fails while a stamp still
records a Blocker or Major: fix them in any chat, then re-run `/review-changes` so a new stamp
covers the fixed work.

## Token-class law

Every token paid in this workspace falls into one of three classes. Misidentifying them wastes budget or causes stale context.

| Class | Paid | Examples | Optimization lever |
|---|---|---|---|
| **Instruction** | Every turn, from turn 1 | Always-on rules (`.mdc`), SKILL.md descriptions in the skills catalog, MCP tool schemas | Keep docs thin; do not add always-on rules for anything recoverable from a command |
| **Tool-result** | Once, then re-sent until the context window is compacted | `Read` outputs, shell stdout, tracker MCP results | Prefer retrieval (Search-CloseoutMemory, Resolve-TicketRoot JSON packet) over full-file dumps; compact aggressively |
| **Skill body** | Only when the skill fires (via `/` slash or a pinned mode) | Bug-fix plan, feature-plan, start-ticket SKILL.md body | Safe to be detailed — not paid unless the user explicitly triggers the skill |

**Decision rule:** if a doc is referenced on every ticket, it is instruction tax. Slice it or make it a stub that redirects to the skill reference. If a doc is only needed at one phase, move it to `references/` and make `_shared/` a one-line stub.

**`Ctx%` metric:** context-window occupancy, recorded per **chat** with `report-context` ([harness-verbs.md](harness-verbs.md)) (not ticket lifetime). `/start-ticket` writes `ctxPct.start` (`CtxS%`); `/review-changes` writes `ctxPct.review` (`CtxR%`); `/complete-task` writes `ctxPct.close` (ledger `Ctx%`). `/implement` is not recorded. Use the hook-measured value; never estimate — a blank is honest. When average CtxS% across tickets stays high, a context-loader MCP becomes worth prototyping.

**Hooks that enforce this law:** the session-start hook injects a `Resolve-TicketRoot` packet (tool-result, once). The read guard denies closeout dumps so agents use `Search-CloseoutMemory.ps1`. Workflow skills that write branches/PRs/tracker set `disable-model-invocation` so their bodies stay skill-class, not instruction-class.

## Conflicts with static analysis

If a quality-gate native severity disagrees with the team scheme above, record the mapping in an overlay rule — do not invent a severity.
