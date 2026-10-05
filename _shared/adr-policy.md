---
name: adr-policy
description: ADRs are the source of truth for accepted architectural decisions. How to consult, cite, and propose them from ticket planning and implementation.
keywords: ADR, architecture decision record, adrIndex, accepted decisions, consult, cite, propose, conflict
---

# ADR Policy

Architecture Decision Records (ADRs) capture accepted, numbered decisions on data access, error
handling, DI, validation, naming, and similar cross-cutting concerns. This doc governs how the
ticket workflow (`/start-ticket`, `/implement`, specialists) uses an ADR corpus.

**When to consult:** only when `adrIndex` in the manifest is non-null (copied from `profile.adrIndex`
by the ticket router). Do not load ADRs for repos without one. If your project has no ADR corpus,
`adrIndex` stays `null` and this doc is never loaded.

## Consult before proposing a pattern

Any plan step or implementation change that touches an architectural concern loads the index at
`adrIndex` first (it is short; load the whole thing). Open an individual ADR only for the category
the ticket touches — do not read the whole corpus up front. Skipping the index is how a plan
reinvents a decision an ADR already made.

## Cite what the plan follows

Cite every ADR a step follows by number and short name — in the **Plan Digest** (`ADRs followed:
ADR-042, ADR-017`) and, where it helps, on the step itself:

```markdown
6. [med] Add the payment handler branch — result type per ADR-0002, DI per ADR-0005.
```

A step that follows no ADR (pure business logic) says nothing. Cite only steps making an
architectural choice.

## Conflict: plan step vs. an Accepted ADR

Do not silently deviate and do not silently comply. Either:

1. **Change the step** to follow the ADR. This is the default.
2. **Flag the conflict** to the user — name the ADR, quote the one conflicting line, explain why
   this ticket seems to need something different. The user decides; a ticket plan never overrides an
   Accepted ADR unilaterally.

During `/implement`, a step that contradicts an ADR once the code is visible is **not** a routine
refinement — stop and ask, as for a step that would change acceptance criteria.

## New precedent: no ADR covers this

When a step introduces a genuinely new architectural pattern (not "which existing pattern to use"),
draft a stub using the corpus's own template:

- Placeholder filename and number (never pick a real one); `status: Proposed`.
- Include it in the ticket's diff like any other file.

**Hard limits:**

- Never set an ADR's status to Accepted or assign a real number; a human-approved PR does that.
- Never hand-edit a generated index.
- Never treat a stub as decided. Tell the user it needs reviewer sign-off through a normal PR before
  any other code relies on it.

## Where this plugs in

Planning (`skills/start-ticket/references/*`): consult + cite. Execution (`skills/implement`): ADR
conflicts escalate. Closeout (`skills/complete-task`): the approval package notes which ADRs the
change follows and flags any unapproved stub.

## Guardrails

- Consult the index, not the whole corpus. Cite by number + short name; never paste a full ADR.
- An ADR conflict is always visible to the user, as "followed ADR-000X" or an explicit flagged
  conflict — never a silent choice either way.
