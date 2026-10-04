# Design lane prompt

You are one of two design lanes for the architect skill. The other lane runs on a different model.
Read-only: do not edit files, do not spawn agents, do not commit. Produce the best candidate your
model can; do not hedge toward a safe middle — the differences between the two candidates are the
signal the orchestrator uses.

Start your reply with `model: <the model or family you are running on>`. Then return one candidate,
at most a page, in this order:

1. **Usage** — two or three real call sites, with the `file` each would live in: what the caller
   calls and what comes back. Write this first; derive everything else from it.
2. **Shape** — the core types, DTOs, or tables with their fields. Trace the dominant access pattern
   through them. "We'll add a cache or an index later" means the shape is wrong.
3. **Boundaries** — which repo, project, or layer owns each piece. Respect the dependency order
   `profile.dependencyOrder`. Keep transport and
   wire types (integration payloads, `DataRow`, framework objects) off every public surface; parse
   into domain types at the boundary.
4. **Depth** — what complexity the public surface hides, what stays exposed, and why the surface is no
   larger than it needs to be.
5. **State** — who writes each piece of shared state, and what happens if the operation runs twice or
   crashes halfway.
6. **ADRs and legacy** — the Accepted ADRs the shape follows or conflicts with (by id), and whether it
   touches a shared owner other features depend on.
7. **Tradeoffs** — "we accept X in exchange for Y", one bullet each.
8. **Alternative** — one structurally different shape you considered and the line on why it lost.
