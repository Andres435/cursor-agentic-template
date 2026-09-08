---
name: closeout-search
description: How start-ticket searches prior ticket memory so past gotchas feed the next ticket without dumping every plans/ file into context.
keywords: closeout search, priorFindings, ticket memory, closeout-index, lessons, Search-CloseoutMemory
---

# Closeout Search (ticket memory)

`plans/closeout-index.md` is the compounding knowledge store: one dense row per durable lesson, and
the only surface worth searching. Search it, then keep at most **8** compact lessons on the manifest.

Do **not** read `plans/WI*-closeout.md` files. Those exist only for the rare ticket whose
retrospective earned a page ([task-retrospective.md](task-retrospective.md)), and the lesson from any
such ticket is already in the index.

## When

During [../SKILL.md](../SKILL.md), after classification
axes are filled and **before** writing the manifest. Also re-run if scope changes (new repo or
integration).

## How

1. Build a query from the work-item title, area, `integration`, `affectedRepos`, and obvious
   keywords from the ticket's title, area, integration, and affected repos.
2. Prefer the script (compact JSON):

   ```powershell
   .\.cursor\scripts\ticket\Search-CloseoutMemory.ps1 -Query "<title keywords>" -MaxResults 8
   ```

   Fallback: `Grep` `plans/closeout-index.md` directly.
3. Copy the returned bullets into manifest `priorFindings[]` (`ticket` + one-line `lesson`).
4. Do **not** add closeout files to `docSet`. If a lesson needs detail and that ticket happens to
   have a `WI<n>-closeout.md`, read **only** its **Other findings** slice.

## Guardrails

- Skip when there are no closeouts / index yet; `priorFindings` is `[]`.
- Ticket-specific leftovers (unstaged Web.config, unrelated PRs) stay out of `priorFindings`.
- Durable setup that repeats belongs on an environment card; the index is the retrieval surface
  until a card exists.
