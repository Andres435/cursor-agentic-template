---
name: tdd-red-green-refactor
description: Test-first loop. Use when the user asks for TDD or when a regression test should fail before the fix.
keywords: TDD, red green refactor, characterization, regression
---

# TDD — red, green, refactor

1. **RED** — smallest test that fails for the right reason (or a characterization test that
   documents current behavior).
2. **GREEN** — smallest production change that passes that test.
3. **REFACTOR** — only while green.

The project's test runner lives in `environments/local-dev.md`. Do not invent a command the
profile never named.
