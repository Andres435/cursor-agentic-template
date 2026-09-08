---
name: review-protocol
description: Shared review focus areas and rule sources for code reviews, pre-merge checks, and review-oriented agents or commands.
keywords: review focus areas, rule sources, pre-merge, review-only, conventions
---

# Review Protocol

Use this protocol for code reviews, pre-merge reviews, and review-oriented agent reports. Use
[severity-and-output.md](severity-and-output.md) for severity labels, finding format, caps, and
report shape.

## Slices (load only what you need)

- **Sources** → `## Rule Sources` (which rule files apply to this diff).
- **Focus** → `## Review Focus Areas` (the `review-diff` checklist).
- **Output** → `## Output` + [severity-and-output.md](severity-and-output.md).

## Rule Sources

Load only the rules relevant to the diff's languages and file types. Common starting points:

- Linting / style rules from `rules/` that match the changed languages.
- Cross-repo dependency and commit discipline: `_shared/cross-repo-workflow.md` (when multi-repo).
- Workspace repo map: `rules/workspace-context.mdc`.

**Project-specific rules:** add your own `rules/*.mdc` files and list them here as an overlay.

If a referenced rule source is missing, note it as "source unavailable" in the review rather
than skipping silently.

## Review Focus Areas

- **Correctness** — behavior changes match the ticket, edge cases handled, regression paths covered.
- **Conventions** — naming, visibility, async patterns, and local project style.
- **Architecture** — service boundaries, DI registration, dependency direction.
- **Security** — parameterized queries, no secrets, no PII in logs, authorization on sensitive endpoints.
- **Tests** — new behavior has focused tests; bug fixes have regression tests or a clear reason tests
  are not practical.
- **Database alignment** — when schema changes, verify all affected migration/query paths stay aligned.

**Overlay:** add project-specific focus areas below (e.g. C-class guards, parity alignment, SSDT rules).

## Output

Use the standard report shape from [severity-and-output.md](severity-and-output.md). Default to
Blocker and Major findings unless the user asks for full detail.
