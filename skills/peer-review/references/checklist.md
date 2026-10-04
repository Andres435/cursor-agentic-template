---
name: peer-review-checklist
description: Human-review checklist for /peer-review — naming, folder/organization, validity. Complements pipeline pr-merge-review.
keywords: peer review, naming, folder, organization, validity, reuse
---

# Peer review checklist

Use to judge coworker PR diffs. Pipeline CodeReview already posts Blocker/Major bot findings.
Leave comments a careful human would leave after reading the change. Do not restate a
pipeline thread.

Judge against sibling types in the same area. Do **not** cite internal docs in posted comment
text — see [comment-voice.md](comment-voice.md).

## Look for

- **Naming** — type/method/file names that are convention-legal but wrong for the domain
  (a module prefix that neighbors do not use, a boolean method without the prefix neighbors use).
- **Organization / folder** — new types dumped in a catch-all folder; namespace not matching
  folder; file in the wrong project or layer.
- **Validity** — change does not match the work item; a comment disagrees with the executable
  line; dead or misleading API; a type used as the wrong kind of object.
- **Reuse** — a parallel helper when an existing one in the same area already does the job.
- **Cross-repo** — a field that does not match across linked pull requests.
- **Shared owner** — flag edits to code another team owns; do not suggest rewriting it unless
  that is the ticket.

## Do not raise

- Anything already on an existing thread (bot or human) for that path/line/ask.
- Markdown/YAML/ADR format issues owned by CI Layer A.
- Drive-by style with no team convention behind it.
- Generic “looks good”, “please add tests” with no location, or a restatement of a pipeline finding.

Keep only comments a careful human would actually leave. Cap at **10** proposed comments per PR.
Drop the rest. Never label them Blocker/Major/Minor/Nit in the draft or in the tracker.
