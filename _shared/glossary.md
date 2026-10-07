---
name: glossary
description: One-line meanings for the workflow's own terms (ticket, mode, manifest, epoch, ctxPct, lanes, receipts, tiers) with the doc that owns each.
keywords: glossary, terms, ticket, mode, manifest, docSet, epoch, ctxPct, CtxS, lanes, receipt, reviewReady, stackSmoke, deepLane, tier, Plan Digest, Deviations
---

# Glossary

One line per term; the owner doc has the rule. Not loaded by default: read it when a term is unclear.

| Term | Meaning | Owner |
|---|---|---|
| `<ticket>` | A ticket id: the tracker id, the ticket branch name, and the `plans/` file prefix (`profile.ticketPrefix`). | [profile.json](../profile.json) |
| Mode | Where a ticket's work happens: `branch` (canonical clones), `worktree` (the ticket worktree), or `investigate` (spike, read-only). | [ticket-artifacts](ticket-artifacts.md) |
| Manifest | `plans/<ticket>-manifest.json`, the one record per ticket: classification plus every stamp below. | [ticket-artifacts](ticket-artifacts.md) |
| `docSet` | The docs the router picked for this ticket; later chats load these and nothing broader. | [ticket-router](../skills/ticket-router/SKILL.md) |
| Load map | The table in the start-ticket playbook naming each doc (or section) the start chat loads, and when. | [start-ticket](../skills/start-ticket/playbooks/start-ticket.md) |
| Plan Digest | The short top section of an approved plan that later chats read instead of the whole plan. | [ticket-plan-output](ticket-plan-output.md) |
| Engineering Decisions | The plan section that records each design choice and its rejected alternative. | [engineering-decisions](engineering-decisions.md) |
| Deviations | Plan section listing what the build changed from the approved plan. | [ticket-plan-output](ticket-plan-output.md) |
| `[low]` / `[med]` / `[high]` | Difficulty tag on each Work Plan step; picks its tier. `[high]` also needs an architect result. | [model-routing](model-routing.md#difficulty-rubric) |
| Tier | `fast` / `standard` / `deep` / `frontier`: a capability level, mapped to a model per IDE. | [model-routing](model-routing.md) |
| `deepLane` | Whether an IDE runs deep work `inline` in the chat or `dispatch`es it to a deep subagent. | [adapters](../adapters/README.md) |
| Engineering mode | A chat that orchestrates: each step goes to its tier's model. | [engineering-mode](../skills/engineering-mode/SKILL.md) |
| Lane | One dispatched subagent run (planner, architect, `review-diff`, or an implement run of same-tag steps). | [model-routing](model-routing.md#dispatch-rules) |
| `lanes` (manifest) | Count of lanes per tier, e.g. `f2/s1/d0 inline:d3`; the ledger's Lanes column. | [Set-TicketLanes](../scripts/ticket/Set-TicketLanes.ps1) |
| Subagent function | A reusable read-only subagent with a fixed packet shape (`explore-repo`, `review-diff`, ...). | [subagent-functions](subagent-functions.md) |
| Receipt / stamp | A manifest field a script writes to prove a step ran on the current work: `verify`, `reviewReady`, `stackSmoke`, `feedback`. | [ticket-artifacts](ticket-artifacts.md) |
| `reviewReady` | Review verdict per repo plus the reviewed work (`headSha`, fingerprint). Close and skip both check it still matches. | [Set-ReviewReady](../scripts/ticket/Set-ReviewReady.ps1) |
| `verify` | verify-repo result per repo, with the work it ran on. Close fails when the tests ran on older work. | [Set-VerifyReceipt](../scripts/ticket/Set-VerifyReceipt.ps1) |
| Drive | Walking the changed flow in the browser on a running stack. Only the user says a Drive passed; `stackSmoke` records it. | [runtime-verify](runtime-verify.md) |
| `stackSmoke` | User-confirmed Drive of the changed flow. A close gate when an affected repo has profile layer `frontend`. | [Set-StackSmoke](../scripts/ticket/Set-StackSmoke.ps1) |
| Fingerprint | SHA-256 of the canonical diff (`fpVersion` 2) that names "the work" for stamps. | [ManifestFields](../scripts/ticket/lib/ManifestFields.ps1) |
| `ctxPct` | How full each chat's context window was: `start`, `review`, `close`. Hook-measured or blank, never estimated. | [Set-TicketCtxPct](../scripts/ticket/Set-TicketCtxPct.ps1) |
| `CtxS%` / `CtxR%` / `Ctx%` | Ledger columns for `ctxPct.start` / `.review` / `.close`. | [task-retrospective](../skills/complete-task/references/task-retrospective.md) |
| E / C / `$tok` | Ledger scores 1-5: Efficiency, Contextualization (right docs loaded), Cost in tokens. | [task-retrospective](../skills/complete-task/references/task-retrospective.md) |
| Ledger | `plans/ticket-ledger.md`, one user-local row per closed ticket. | [task-retrospective](../skills/complete-task/references/task-retrospective.md) |
| Epoch | A hash of the watched workflow contract. A contract change starts a new epoch; after `epochRerateAfter` closes it asks for a re-rate. | [Assert-WorkflowEpoch](../scripts/ticket/Assert-WorkflowEpoch.ps1) |
| Gate | A script that fails closed: `Assert-TicketArtifacts -Phase` (start, implement, prepush, close), `Assert-AgenticFlow`, `Assert-DocLinks`, `Assert-DocBudget`, `Assert-DocSync`. | [Assert-AgenticFlow](../scripts/ticket/Assert-AgenticFlow.ps1) |
| Doc claim | A workflow fact in `scripts/ticket/doc-claims.psd1` that docs must state and never contradict, anchored to the code that makes it true. | [doc-claims](../scripts/ticket/doc-claims.psd1) |
| `Docs-Unaffected:` | Commit trailer that waives one doc-sync rule with a reason, when a code change needs no doc change. | [Assert-DocSync](../scripts/ticket/Assert-DocSync.ps1) |
| Branch mode is three chats | `/start-ticket` (plan + build), `/review-changes`, `/complete-task`. | [USER-MANUAL](../USER-MANUAL.md) |
