---
name: tech-spike
description: Plan and conduct technical investigations. Use when the user asks for a spike, research, feasibility analysis, options comparison, proof of concept, or architectural investigation.
keywords: spike, research, feasibility, investigation, timebox, findings
---

# Technical Spike / Investigation

## Purpose

Guide technical investigations from problem framing through research, options, recommendation, documentation, and confidence scoring.

## First: Gather Input

Before starting the investigation, ask the user for the following if not already provided in this message:
- **Work item number**: ADO work item ID such as `WI12345` or `AB#12345`
- **Title**: Name of the spike
- **Objective**: What question(s) are we trying to answer?
- **Background**: Why is this investigation needed?
- **Scope & Constraints**: Time-box, technical constraints, or boundaries
- **Success Criteria**: What deliverables are expected?

If the user provides a work item number, use [/start-ticket](../../../../commands/start-ticket.md) before investigating. The startup flow owns the shared ADO intake, required-field gate, automatic **Ready for Dev** -> **In Progress** transition, latest `dev` update, `WI<ticketNumber>` branch creation, and then this spike plan.

If ADO blocks the State transition because required fields are empty, report the blocking fields and continue the spike.

If the user pasted a work item or ticket instead of an ID, extract these from it and ask for the work item number if the ticket should be fetched or updated in ADO. Once you have enough context, proceed.

## Instructions

**Switch to Plan mode automatically** and build the full spike plan there. Follow [../../../../_shared/ticket-plan-output.md](../../../../_shared/ticket-plan-output.md) — the plan lives in Plan mode, not in the chat tab.

When invoked from [/start-ticket](../../../../commands/start-ticket.md), call `SwitchMode` without asking the user to confirm. `/start-ticket` owns approval and the final message: Approved plan, then the copy-paste fence last ([ticket-plan-output.md](../../../../_shared/ticket-plan-output.md)).

Include a numbered **Work Plan** section at the end of the plan. Tag every step `[low]|[med]|[high]` per [../../../../_shared/ticket-plan-output.md](../../../../_shared/ticket-plan-output.md) so implementation picks Auto/Composer vs Grok.

1. **Problem Analysis**:
   - Break down the problem into specific questions to answer
   - Identify unknowns and risks
   - Define what "done" looks like for this spike

2. **Research & Discovery**:
   - Examine relevant existing code patterns across all repos in the workspace
   - Check legacy paths and modern equivalents when both exist
   - When `adrIndex` is set, check the ADR index for a decision that already settles this question
     — a spike's job is to answer what's genuinely open, not re-litigate an Accepted ADR (see
     [../../../../_shared/adr-policy.md](../../../../_shared/adr-policy.md)).
   - When `git blame` or `git log` reveals historical ticket IDs, look them up read-only for context. Do not write to historical tickets.
   - Research external solutions, libraries, or best practices
   - Create proof-of-concept code if needed

3. **Options Evaluation** (minimum 2-3 options, each with):
   - Description of the approach
   - Pros and cons
   - Estimated effort: Low / Medium / High
   - Risk assessment
   - Impact on existing codebase
   - SonarQube compliance implications
   - When `adrIndex` is set: alignment with existing Accepted ADRs, or explicit note that this option
     would need a new one
   - Which repos would be affected — use the dependency order from `profile.json`

4. **Technical Findings**:
   - Key discoveries from code exploration
   - Dependencies or blockers identified
   - Performance or scalability considerations
   - Security implications

5. **Recommendation**:
   - Recommended approach with clear justification
   - Implementation roadmap with repo-by-repo breakdown
   - Open questions or follow-up items
   - If the recommendation sets a genuinely new architectural precedent (not a case already
     covered by an existing ADR), say so explicitly and name it as an ADR-stub candidate for the
     implementing ticket to draft — a spike proposes, it does not draft or accept the ADR itself
     ([../../../../_shared/adr-policy.md](../../../../_shared/adr-policy.md)).

**Conclude with a Summary**:
- Key findings (bullet points)
- Recommended next steps
- TmoDocs documentation to create (document findings for future reference)
- Follow-up work items to create

**Confidence Score**:
- Fill out the rubric in [../../../../_shared/confidence-score.md](../../../../_shared/confidence-score.md), using `Findings certainty` as the second-row axis.
- Use **Risks / Unknowns** to capture residual investigation gaps (e.g. "Did not test against production-scale data", "Vendor library behavior under concurrency unverified").
- If `Findings certainty` is Med or Low, the recommendation should be flagged as provisional and a follow-up spike or POC should be proposed.

## Closeout (User-Invoked)

Do not run closeout automatically after the spike summary. When the user is ready to stop and review the work, they invoke [/complete-task](../../../../commands/complete-task.md).
