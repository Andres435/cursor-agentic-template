---
name: test-verification
description: Scoped test policy for ticket work. Load when verifying a change; not always-on.
keywords: tests, scoped tests, regression, verification
---

# Test verification

Run the **smallest** test that proves the change. Prefer the nearest fixture or project over a
full-repo suite.

1. Search for existing tests around the affected behavior.
2. Bugs: if a relevant test already fails, that is RED. If none exists, add the smallest regression
   test, then the production change, then re-run that test.
3. Features: convert acceptance criteria into observable tests for the slice you are shipping.
4. Quote pass/fail counts. Do not paste full logs unless the user asks.

The project's test command belongs in `environments/local-dev.md` (overlay). Do not invent a
runner the profile never named.
