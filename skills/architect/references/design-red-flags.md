# Design red flags

Screen every candidate before choosing. A flag means revise or reject that shape.

## Structure (from pstack)

- **Shallow module** — a large interface that hides little. Callers coordinate several methods to
  finish one operation, or public options expose internal stages. Learning the interface does not
  save the caller from learning the implementation.
- **Information leakage** — one representation, policy, or protocol detail known in several modules,
  so changing it needs coordinated edits. Re-exporting a wire type is leakage.
- **Temporal decomposition** — modules split by execution order (load, validate, transform, save)
  instead of by the knowledge they own, repeating one representation across every boundary.
- **Pass-through method** — forwards the same arguments to another method of the same shape and adds
  a layer without hiding anything. Keep a forwarding boundary only when it adds policy or adaptation.

## Project

- **Shared-owner edit where a local change meets the acceptance criteria.** Suggest, then ask-user — never default to it.
- **Conflict with an accepted decision when `profile.adrIndex` is set.** That is the user's decision, not a design detail.
- **Cross-repo contract out of dependency order**, or a consumer shipped before its producer.
- **A schema change the manifest did not declare** (`dbChange: false`).
- **Wire types on a public API** — integration payloads, `DataRow`, or framework objects instead of
  parsed domain types.
