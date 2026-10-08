---
name: performance-ci
description: What a review should flag for query cost and a missing pipeline gate.
keywords: performance, N+1, unbounded query, CI, pipeline gate
---

# Performance and CI

Flag these in the diff. Do not propose a query change that is not in the change.

## Queries

- A list query with no upper bound (`Take`, `TOP`, or paging) on a table the user can grow.
- N+1: one query per row inside a loop over the rows a first query already returned.
- Loading a full entity when the caller uses two columns.

## Pipeline

- A new project or workflow with no test step.
- A pipeline that lets a failing test or a failing analyzer through.
