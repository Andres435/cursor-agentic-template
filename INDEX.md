# Index

One row per doc. Search here before Grep. Add your overlay docs to the bottom table.

## Core docs (do not edit paths)

| Doc | Purpose | Keywords |
|---|---|---|
| [CUSTOMIZE.md](CUSTOMIZE.md) | Checklist `/start-new-project` fills | customize, profile, setup, first ticket |
| [commands/start-new-project.md](commands/start-new-project.md) | New product interview — writes profile.json | start-new-project, profile, local-dev |
| [TEMPLATE.md](TEMPLATE.md) | Maintainer map: core vs overlay | core, overlay, upgrade, versioning |
| [README.md](README.md) | What this is; quick start | template, clone, start, overview |
| [MACHINE-SETUP.md](MACHINE-SETUP.md) | First-time machine bootstrap | setup, extensions, folder layout |
| [AGENTS.md](AGENTS.md) | Agent index and routing | agents, specialists, routing, manifest |
| [USER-MANUAL.md](USER-MANUAL.md) | Day-to-day ticket lifecycle | start-ticket, implement, complete-task, prep-pr, chat lifecycle |
| [profile.json](profile.json) | Project config | repos, ticketSystem, specialists, startCommand |
| [_shared/ticket-artifacts.md](_shared/ticket-artifacts.md) | Phase gate contract — what files each phase produces | artifacts, gate, manifest, plan, closeout |
| [_shared/ticket-plan-output.md](_shared/ticket-plan-output.md) | Plan and closeout structure | plan digest, work plan, deviations, startup message |
| [_shared/severity-and-output.md](_shared/severity-and-output.md) | Severity labels, finding format, token-class law | blocker, major, findings, token, instruction |
| [_shared/subagent-functions.md](_shared/subagent-functions.md) | Subagent fan-out contracts | subagent, explore-repo, branch-setup, verify-repo, review-diff |
| [_shared/review-protocol.md](_shared/review-protocol.md) | Review focus areas and rule sources | code review, conventions, security, tests |
| [_shared/model-usage.md](_shared/model-usage.md) | Pointer to the tier contract | tier, adapter |
| [_shared/model-routing.md](_shared/model-routing.md) | Tier contract for plans and lanes | tier, fast, standard, deep |
| [_shared/harness-verbs.md](_shared/harness-verbs.md) | IDE-neutral verbs | ask-user, dispatch, enter-plan |
| [_shared/engineering-principles.md](_shared/engineering-principles.md) | Principles cited from a plan | principles |
| [_shared/adr-policy.md](_shared/adr-policy.md) | ADR consult/cite policy — load when adrIndex is set | ADR, architecture decision, consult, cite |
| [_shared/runtime-verify.md](_shared/runtime-verify.md) | Token rails for stack and UI verify | stack recycle, UI verify, retry policy |
| [_shared/engineering-decisions.md](_shared/engineering-decisions.md) | Plan decision gate — open calls stop the plan | engineering decision, TBD, out of scope |
| [_shared/test-verification.md](_shared/test-verification.md) | Scoped tests | tests, regression |
| [_shared/cross-repo-workflow.md](_shared/cross-repo-workflow.md) | Multi-repo order from profile.dependencyOrder | multi-repo, dependency order |
| [playbooks/start-ticket.md](skills/start-ticket/playbooks/start-ticket.md) | Start-ticket full steps | intake, plan, branch, worktree |
| [skills/ticket-router/SKILL.md](skills/ticket-router/SKILL.md) | Ticket classifier — emits the work manifest | router, manifest, affectedRepos, docSet |
| [skills/ticket-context-load/SKILL.md](skills/ticket-context-load/SKILL.md) | Fresh-chat hydrate | load profile, complete-task, implement |
| [skills/review-changes/PLAYBOOK.md](skills/review-changes/playbooks/review-changes.md) | Review steps | review, diff, staged, pre-merge |
| [plans/examples/ticket-ledger.example.md](plans/examples/ticket-ledger.example.md) | One row per closed ticket (E/C/$tok/Ctx%) | ledger, scorecard, closed tickets |
| [plans/closeout-index.md](plans/closeout-index.md) | Compact durable lessons from closeouts | memory, lessons, closeout, priorFindings |

## Your overlay docs

> Add rows here as you create project-specific files.

| Doc | Purpose | Keywords |
|---|---|---|
| [agents/fullstack-specialist.md](agents/fullstack-specialist.md) | Fullstack specialist stub | fullstack, specialist |
| [environments/local-dev.md](environments/local-dev.md) | Local dev env card | local dev, ports, start |
