---
name: adr-policy
description: ADRs are the source of truth for accepted architectural decisions. How to consult, cite, and propose them from ticket planning and implementation.
keywords: ADR, architecture decision record, adrIndex, accepted decisions, consult, cite, propose
---

# ADR Policy

Architecture Decision Records (ADRs) capture accepted, numbered decisions on data access, error
handling, DI, validation, naming, and similar cross-cutting concerns. This doc governs how the
ticket workflow (`/start-ticket`, `/implement`, specialists) uses an ADR corpus.

**When to consult:** only when `adrIndex` in the manifest is non-null. Do not load ADRs for
repos without one. The ticket router sets `adrIndex` only when the affected repo has an ADR tree.

## Consulting ADRs

1. Read the ADR index at `adrIndex` to find relevant decision numbers.
2. Load only the specific ADR docs that apply to the area being changed.
3. Cite by number in the plan's **Plan Digest** (`ADRs followed: ADR-042, ADR-017`).
4. Do not re-decide what an accepted ADR settled. If a decision is wrong for this ticket,
   propose an amendment — do not silently deviate.

## Proposing a new ADR

1. State the problem, the options, and the chosen option with rationale.
2. Submit as a PR to the project's ADR directory for review.
3. Do not implement a pattern that contradicts an accepted ADR before the amendment is merged.

## Scope

This file applies to whatever `adrIndex` points at in the project. If your project has no ADR
corpus, `adrIndex` stays `null` and this doc is never loaded.
