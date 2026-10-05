---
name: implement-skill
description: Run a ticket's already-approved plan in a fresh chat. Loads the manifest, plan, and doc set from .cursor/plans/ instead of re-planning, executes the Work Plan in order, and stops for review.
keywords: implement, execute plan, worktree window, resume, grounded refinement, deviations, scoped tests, engineering mode
disable-model-invocation: true
---

# Implement

Executes an approved plan in a **fresh chat**. Reasons to be here:

1. **Worktree mode** — `/start-ticket --worktree` planned in one window; this is the build chat, run
   in a chat rooted at the ticket worktree it created.
2. **Resuming branch mode** — `/start-ticket` normally plans *and* builds in one chat. If that chat
   ran out of context or was closed, this command picks the plan back up.

A spike (`mode: investigate`) may resume here the same way, still read-only on the canonical clones.
Do not create or check out `<ticket>`, and do not edit product code.

If you are in the chat that just approved the plan in branch mode, you do **not** need this command —
keep going there (`start-ticket.md` step 9). Loading state you already hold is the cost branch mode
exists to avoid.

## Invocation

```text
/implement <ticket>
```

Optionally followed by pointer lines (plan path, root, one constraint). Ask for the ticket id if it
is missing.

## What this command is

`/start-ticket` already did intake, classification, branch/worktree setup, and planning. This command
**executes** that plan. It is not a planning command and not a review command.

- You **follow** the approved Work Plan step by step.
- You **may refine** a step when the real code contradicts the plan (see Grounded refinement).
- You **do not** re-plan from scratch, re-run `/start-ticket`, or re-derive scope.

## Workflow

1. **Load ticket state**
   - Run [../../ticket-context-load/SKILL.md](../../ticket-context-load/SKILL.md) with
     `-Phase implement`. It resolves the ticket's mode and root, runs the artifacts gate, and loads
     the manifest, approved plan, `docSet`, environment card, and `priorFindings`.
   - In **worktree** mode this chat must be rooted at the ticket worktree. If it is not, say so and
     stop; the user opens one that is, per
     [adapters/README.md](../../../adapters/README.md#open-a-ticket-worktree)
     ([../../../environments/worktrees.md](../../../environments/worktrees.md)).
   - If context-load reported a repo behind `origin/<baseBranch>`, merge it now, before the first
     edit, while the index is clean. Stop and report on a conflict. This is the only build chat that
     merges the base before `/prep-pr` (branch-setup may already have merged it at start).
   - If the gate fails, stop. Report what is missing and offer to reconstruct it. Do not substitute
     a plan of your own.

2. **Restate the plan for confirmation (short)**
   - Echo the numbered Work Plan with its `[low]|[med]|[high]` tags and the current step. One block,
     no re-derivation, no alternatives.

3. **Execute steps in order**
   - One numbered step at a time. Cross-repo order from
     [../../../_shared/cross-repo-workflow.md](../../../_shared/cross-repo-workflow.md).
   - Read the affected repo's own conventions before editing it.
   - **Engineering mode off (default):** execute each step inline. `dispatch` a manifest
     `specialists[]` agent when a step needs domain depth, scoped to the step, on that step's tag
     tier ([../../../_shared/model-routing.md](../../../_shared/model-routing.md); models: the IDE
     adapter, [../../../adapters/README.md](../../../adapters/README.md)).
   - **Engineering mode on:** route every step by its tag under the contract's dispatch rules. Deep
     and `[high]` follow the adapter's `deepLane` (inline on the chat's model, or a deep lane).
     `[low]` and `[med]` go to a lane — contiguous same-tag steps in the same repo share one — with
     the step's specialist as the agent and the tier's model. If that lane is discarded, run the
     step inline and say so once; a discarded lane does not skip the step. Review each lane's diff
     before reporting the step; log an escalation as a Deviation. Do not report `step N/M done`
     while the chat is still in plan mode.
   - Report progress as `step N/M done` (engineering mode: `step N/M [tag] → inline | lane (<model>)`).
     Do not narrate every file read.
   - When the plan groups three or more behaviors, finish and verify one behavior group before
     starting the next. Foundational steps still come first.

4. **Grounded refinement (when the plan meets reality)**
   - The plan was built from the ticket before the code was searched, so a step can be wrong about a
     file, a symbol, or an order. When that happens:
     1. Say what the plan assumed and what the code shows — one or two lines.
     2. Make the smallest adjustment that still meets the acceptance criteria.
     3. **Before** reporting `step N/M done`, append a dated line to the **Deviations** section of
        `.cursor/plans/<ticket>-<type>-plan.md` (create the section if absent):
        `- <date> step N: <assumed> → <actual>; <what changed>`. Silent divergence is the failure
        mode this section prevents — Deviations must be on disk so `/complete-task` reads them
        without loading the Work Plan.
   - **Stop and ask instead of refining** when the change would alter acceptance criteria, add a
     repo not in `affectedRepos`, introduce a schema or API contract the ticket did not name,
     contradict an Accepted ADR the plan cited ([../../../_shared/adr-policy.md](../../../_shared/adr-policy.md))
     — an ADR conflict is a decision for the user, not a code-shape refinement — or when a
     comment/doc disagrees with the executable statement (not a routine refinement).
   - **Shared / framework types:** if a shared owner is clearly the better fix (the local alternative
     would be incorrect, or the owner is a base type many callers inherit), **suggest it via
     `ask-user`** before touching anything: why it is better, the rejected local alternative, and the
     blast-radius result — run [../../blast-radius/SKILL.md](../../blast-radius/SKILL.md) first and
     carry its safety fact, proof level, and risks into the question. Do **not** implement in
     passing. If the user approves, append a Deviations line and proceed; if not, take the local
     approach or stop.
   - Refinement is always visible in chat *and* in the plan file.

5. **Verify what you changed**
   - Scoped tests per [../../../_shared/test-verification.md](../../../_shared/test-verification.md)
     for the repos you touched; scope to the affected fixture, not the whole solution.
   - Static analysis only for repos that have a project key on the manifest; others are skipped, not
     failed.

6. **Converge — do not edit code in this pass**
   - After the last Work Plan step, compare the diff to the plan's **Behaviors** list (features) or
     to the acceptance criteria (bugs). A step being done is not the same as a behavior being met.
   - Report only what is missing. If nothing is missing, say so in one line and go to step 7.
   - If something is missing, either do that work before the summary, or stop and ask. Do not close
     the gap by editing code inside this pass.
   - A dated **Deviations** line is only for a gap the user says is out of scope. Do not record a
     real miss as a deviation so the summary can say done.

7. **Stop for review**
   - Summarize to the [chat output budget](../../../_shared/severity-and-output.md#chat-output-budget):
     steps completed, files changed per repo, tests run and outcome, any Deviations recorded,
     anything deliberately left out.
   - Tell the user to stage what they want reviewed, then run `/review-changes` in a **separate new
     chat**, then `/complete-task` in another new chat. Do **not** record `ctxPct.start` from this
     command (`/implement` occupancy is not tracked). Do record the lane mix:

     ```powershell
     .\.cursor\scripts\Set-TicketLanes.ps1 -Ticket <ticket> -Lanes "<fN/sN/dN inline:dN, or off>"
     ```

     Pass `off` when engineering mode was off; never invent a mix.

## Guardrails

- Do not commit, push, create PRs, or write the tracker. That is `/complete-task` → `/prep-pr`.
- Do not run `/start-ticket`, the ticket router, or a tracker fetch from this command.
- Do not read `plans/*-closeout.md`; the manifest's `priorFindings` is the compact answer.
- Do not widen scope past the manifest's `affectedRepos` without asking.
- Do not start the local stack — the user runs `/start-stack` when they want the apps.
- Do not continue into closeout in this chat.
