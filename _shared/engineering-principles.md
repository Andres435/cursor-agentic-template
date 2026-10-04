---
name: engineering-principles
description: Eight engineering principles the workflow applies when planning, designing, and reviewing, adapted from pstack. Read at the Engineering Decisions step; cited by architect, blast-radius, and code-reviewer.
keywords: principles, subtract before you add, laziness, model the domain, data shape, boundary discipline, root cause, prove it works, verifiable units, test behavior, encode lessons, pstack
---

# Engineering Principles

Eight of pstack's principles (Lauren Tan, MIT — [../THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md)),
rewritten for this workspace. In a plan, name a principle only where it changed a decision, in that
decision's **Why** line. A principle that changed nothing is not cited.

## 1. Subtract before you add

When sizing a diff, refactoring, or tempted to add a layer, flag, or wrapper. Delete dead weight
first, then build on the simpler base. The smallest change that meets the acceptance criteria wins;
a one-caller wrapper is a cost, not a courtesy.

## 2. Model the domain

Before logic that branches a lot or repeats a shape assumption across files. Name the data shape
first, then choose its organizing structure: a state machine over scattered booleans, a lookup table
over a long `If`/`Select Case` ladder, a typed DTO over repeated `DataRow` column reads. When `profile.adrIndex` is set, those decisions already settle most shapes ([adr-policy.md](adr-policy.md)).

## 3. Boundary discipline

When wiring validation, error handling, or an integration adapter.
Validate and parse at the system boundary into domain types, trust those types inside, and keep
business logic free of transport and framework objects.

## 4. Fix root causes

When debugging. Reproduce first, then ask why until you reach the mechanism. A change that only hides
the symptom — an extra null check, a retry, a catch — is a hypothesis, not a fix. When evidence
refutes it, revert what it motivated.

## 5. Prove it works

Before declaring a step done. Verify against the real artifact on the matching surface — the scoped
test, the running page, the actual query result — not "it compiles". Inconclusive is a fail
([test-verification.md](test-verification.md), [runtime-verify.md](runtime-verify.md)).

## 6. Sequence verifiable units

For Work Plans, migrations, and cross-repo changes. Each unit ends in a check you run before the next
starts, ordered so earlier units prove the later ones' assumptions: the failing regression test
before the fix, the schema before the proc that reads it.

## 7. Test behavior, not implementation

When writing or keeping a test. Assert observable behavior or a contract, and confirm the test fails
while the defect is present. Keep negative-path and relational tests; drop tests that only restate the
implementation.

## 8. Encode lessons in structure

When you catch yourself writing the same instruction twice. Make it a check, a script, a type, or a
gate instead of another sentence.
