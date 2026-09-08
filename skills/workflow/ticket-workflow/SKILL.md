---
name: ticket-workflow
description: Standard workflow for starting and completing a TMO ticket. Use to gather ticket context, load environment setup, identify affected repos, plan bug or feature work, verify changes, prepare review, and produce confidence scoring.
keywords: ticket lifecycle, end-to-end, workflow map, phases, narrative
---

# Ticket Workflow

Standard process for working on a ticket from intake through verification.

**Role of this file:** a conceptual map of the whole lifecycle, cross-linking the docs that actually
own each step. It does not execute anything itself. [commands/start-ticket.md](../../commands/start-ticket.md)
owns Steps 1–5 end-to-end (ADO intake, router, worktree, branch setup, Plan mode) and
[commands/complete-task.md](../../commands/complete-task.md) owns Step 8. If this file and either
command ever disagree on a mechanic, the command is authoritative — update this file to match, not
the other way around. Load this skill when you want the big-picture narrative or a jumping-off point
into the per-step docs; invoke the commands directly for the actual work.

## Step 1: Understand The Ticket

Gather these details (ask the user if not provided):
- Ticket number/ID
- Title and description
- Type: feature, bug fix, tech spike, or refactor
- Acceptance criteria or expected behavior

When the user provides an ADO work item number, use [.cursor/commands/start-ticket.md](../../commands/start-ticket.md) before broad code search. The startup flow owns ADO fetch, required-field gate, automatic **Ready for Dev** -> **In Progress** transition, resumed-ticket branch handling (local `WI<n>` without `origin/WI<n>` → default QA rejection/reopen, not completion; recreate from latest `dev`), latest `dev` update, `WI<ticketNumber>` branch creation, the session start timestamp (on `.cursor/plans/WI<number>-manifest.json`), the initial bug/feature/spike plan in **Plan mode** (not chat), and **`Initialize-TicketRuntime.ps1`** after the artifact gate (branch checkout check, feed tokens, npm/pnpm install, Scripts/react bundles when `dist` is empty). In default **branch** mode that same chat then implements the approved plan; only `--worktree` hands off to a second chat. The plan file is persisted so later chats (`/complete-task`, context-overflow `/implement`) can load it — this chat does not re-read it to start building.

If the `Last synced` date in [.cursor/skills/sync-tracked-conventions/manifest.md](../conventions/sync-tracked-conventions/manifest.md) is older than 14 days (or the manifest is missing), suggest running the [sync-tracked-conventions](../conventions/sync-tracked-conventions/SKILL.md) skill before starting so workspace conventions reflect recent changes in tracked rule folders.

## Step 2: Load Environment Context

Use [environment-context](../domain/environment-context/SKILL.md) before broad code search. If a matching card exists under [.cursor/environments/](../../environments/), use it to seed:

- likely repositories and runtime projects
- first search targets
- related feature flags or sandbox modes
- nearest relevant test projects
- integration-specific risks

Do not store ticket-specific findings in environment cards. Only durable reusable setup knowledge belongs in cards.

## Step 3: Scope Analysis

Identify all affected areas:
1. Which repositories need changes? (see `profile.json` repos)
2. Which layers are affected? (database, backend, frontend, docs)
3. Are there integration points between repos?
4. Does this affect shared libraries or packages?

Follow [../../../_shared/cross-repo-workflow.md](../../../_shared/cross-repo-workflow.md) for repository dependency order.
When `git blame` or `git log` reveals historical ticket IDs during scope analysis, look up context read-only. Do not write to historical tickets.

## Step 4: Choose Work Type Flow

### Bug Fix

Use the bug policy from [../../../_shared/test-verification.md](../../../_shared/test-verification.md):

1. Search for existing tests around the affected behavior.
2. If a relevant test already fails for the reported bug, use it as the RED signal.
3. If no existing test proves the bug, add the smallest focused regression test.
4. Make the smallest production change required to pass.
5. Re-run the focused test, then the nearest broader test scope.

### Feature

Plan features as behavior slices:

1. Convert acceptance criteria into observable behaviors.
2. Choose the smallest behavior that proves the path.
3. Prefer [tdd-red-green-refactor](../domain/tdd-red-green-refactor/SKILL.md) for behavior-heavy or risky logic.
4. Avoid writing every test or every implementation detail up front.

### Spike Or Refactor

Use the matching command workflow:

- [tech-spike.md](../../commands/tech-spike.md)
- [review-changes.md](../../commands/review-changes.md)

## Step 5: Create Work Plan

Switch to **Plan mode automatically** and build the work plan there per [../../../_shared/ticket-plan-output.md](../../../_shared/ticket-plan-output.md). Pre-approved by `/start-ticket` — do not ask the user to confirm the switch. Before the final message, `/start-ticket` runs `scripts/Assert-TicketArtifacts.ps1 -Phase start`; the required files are listed once in [ticket-artifacts.md](../../../_shared/ticket-artifacts.md). In **branch mode** (default) the same chat continues to build after the plan is approved — no paste fence. In **worktree mode** (`--worktree`) the last message includes a paste block so the user can start `/implement` in the ticket window.

Include a structured **Work Plan** section. Tag every step `[low]|[med]|[high]` (see [ticket-plan-output.md](../../../_shared/ticket-plan-output.md)):
1. Database / schema changes (if any)
2. Backend service/API changes
3. Frontend component changes
4. Unit tests for new/modified code
5. Documentation updates (for significant features)

## Step 6: Execute

**Branch mode (default):** execution continues in the same `/start-ticket` chat after plan approval. No new chat, no paste block.

**Worktree mode / context overflow:** owned by [/implement](../../../commands/implement.md), run in the ticket worktree window or a fresh chat. It loads state via [ticket-context-load](../ticket-context-load/SKILL.md) rather than re-planning, and logs any plan-vs-reality refinement to the plan file's **Deviations** section.

Work through the plan following the cross-repo workflow:
- Database first, then backend, then frontend
- Read each project's `.cursor/rules/` before making changes
- Follow SonarQube compliance rules (reference [../../../rules/sonarqube-compliance.mdc](../../../rules/sonarqube-compliance.mdc))
- Reference the ticket number in progress notes

## Step 7: Verification

After completing code changes:

- Run scoped tests per [../../../_shared/test-verification.md](../../../_shared/test-verification.md).
- Run SonarQube checks per [../../../_shared/sonar-verification.md](../../../_shared/sonar-verification.md).
- Use [../../../_shared/review-protocol.md](../../../_shared/review-protocol.md) before final review.

## Step 8: Closeout (User-Invoked)

Do not run closeout automatically when implementation or verification finishes.

When the user is ready to stop and review the work, they invoke [/complete-task](../../../commands/complete-task.md). That command owns:

- verification summary
- review readiness
- confidence scoring
- calculated hours and converted story points from session timestamps ([session-time-tracking.md](../complete-task/references/session-time-tracking.md))
- PR title (`WI<number>: <title>`), commit summaries, and ADO field updates (QA notes on ticket; story points on `Custom.StoryPointsActual` after hours conversion — not in PR body)
- approval package presentation
- optional approved `prep-pr` execution
- mandatory [task-retrospective](../complete-task/references/task-retrospective.md) as the final step — always writes one ledger row; writes a `WI<number>-closeout.md` only when the session earned a durable page

Until the user invokes `complete-task`, stop after Step 7 and wait for their review.
