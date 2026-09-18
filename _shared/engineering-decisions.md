---
name: engineering-decisions
description: The decision record every ticket plan carries — what was decided, why, what is explicitly out of scope, and what was rejected. Unresolved items stop the plan instead of defaulting.
keywords: engineering decision, judgment call, scope boundary, out of scope, rejected alternative, open question, TBD, silent default, pre-plan gate
---

# Engineering Decisions

A plan's **Engineering Decisions** section records the calls made *before* the Work Plan exists —
the ones that silently cost a rework pass when they are guessed instead of asked.

## The gate

**An open decision stops the plan.** Ask the user and wait. Do not draft `TBD`, do not write
"resolve during implement", and do not invent a default.

Three things reach the user as a question rather than an assumption:

1. **Ambiguity** — acceptance criteria conflict with the description/repro, or a requirement
   admits two readings.
2. **Scope reach** — a repo, schema change, or external contract the ticket did not name.
3. **Settled-elsewhere conflict** — an Accepted ADR (`profile.adrIndex`) already decided this
   differently, or a `priorFindings` lesson says this exact call went wrong before.

"Skipped — none of these apply" is a valid answer and takes one line. Trivial tickets stay trivial.

## Shape

Each decision is one entry. Five elements, one line each — a paragraph means it is really two
decisions:

```markdown
## Engineering Decisions

- **Decision:** <what was chosen>
  - **Why:** <the constraint or requirement that forced it>
  - **In scope:** <what this ticket delivers>
  - **Out of scope:** <what it explicitly does not, and who owns that instead>
  - **Rejected:** <the alternative considered and why not — or "None considered">
```

Omit `Rejected` only when there genuinely was no fork. Never omit `Out of scope` on a feature or a
cross-repo ticket.

When nothing rises to this weight, the whole section is:

```markdown
## Engineering Decisions

None — <one clause saying why, e.g. "single-file fix, AC unambiguous, no ADR in scope">.
```

## Example

```markdown
## Engineering Decisions

- **Decision:** Call the vendor API with the vendor's enum names, not `enum.ToString()`.
  - **Why:** The remote API rejects the internal name.
  - **In scope:** The request contract for this integration.
  - **Out of scope:** Other vendors' mappings — separate clients, no shared wire format.
  - **Rejected:** A shared enum package — the vendors never share a payload.
```

## Where it goes

| Surface | What it carries |
|---|---|
| Plan file section | The full entries above, placed before the Work Plan |
| Plan Digest `Judgment calls` line | One clause per decision, or `None` ([ticket-plan-output.md](ticket-plan-output.md)) |
| [../plans/closeout-index.md](../plans/closeout-index.md) | Only a decision that proved wrong, recorded at closeout |

A decision that changes after approval is a **new plan**. A decision refined during implementation
with the intent intact is a Deviations entry ([ticket-plan-output.md](ticket-plan-output.md)).

## Work-type candidates

Each work-type template (`bug-fix`, `feature-plan`, `tech-spike`) lists what usually needs deciding.
This file does not restate them. Paths are in [../INDEX.md](../INDEX.md).
