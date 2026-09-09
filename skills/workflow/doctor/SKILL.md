---
name: doctor
description: Verify the workspace is correctly set up for agentic workflow — profile, hooks, artifact gate, and stack start command.
keywords: doctor, health check, setup, profile, hooks, workspace validation
---

# /doctor — Workspace Health Check

Run all checks in order. Print `[PASS]` or `[FAIL] <one-line fix>` for each. Stop after listing
all failures; do not attempt repairs automatically.

## Checks

### 1. profile.json valid

```powershell
Get-Content profile.json -Raw | ConvertFrom-Json
```

Pass if it parses without error and contains: `id`, `ticketPrefix`, `ticketSystem`, `defaultMode`,
`repos`, `stacks.startCommand`. Fail with: `profile.json missing required key '<key>' — see
README.md and CUSTOMIZE.md`.

Also run the full schema gate:

```powershell
.\scripts\ticket\Assert-AgenticFlow.ps1 -WarnOnly
```

This surfaces doc-budget, command-shim, retired-artifact, and ledger-column failures too.

### 2. Hooks runnable

```
node hooks/tests/closeout-guard.test.js
node hooks/tests/session-context.test.js
node hooks/tests/git-push-agentic-flow.test.js
```

Pass if both exit 0. Fail with: `hooks test failed — check node is on PATH and hooks/ is intact`.

### 3. Artifact gate resolves

```powershell
.\scripts\ticket\Assert-TicketArtifacts.ps1 -Ticket WI00001 -Phase start -Root .\scripts\ticket\fixtures
```

Pass if exit 0. Fail with: `Assert-TicketArtifacts failed on fixture — check fixture files in
scripts/ticket/fixtures/plans/`.

### 4. Stack start command exists

Read `stacks.startCommand` from `profile.json`. Check the script path exists:

```powershell
Test-Path -LiteralPath (profile.stacks.startCommand)
```

Pass if the file exists. Fail with: `profile.stacks.startCommand points to missing file — update
profile.json or create the script`.

### 5. Stack -WhatIf (optional)

```powershell
& $profile.stacks.startCommand -WhatIf 2>&1
```

Run only when the user explicitly passes `--stack`. Skip silently otherwise.

## Output

```text
[PASS] profile.json — id: customize-me, ticketPrefix: TICKET-, 1 repo
[PASS] hooks — closeout-guard OK; session-context OK
[PASS] artifact gate — WI00001 start/close pass
[PASS] stacks.startCommand — scripts/runtime/Start-TicketStack.ps1 exists
```

Print a summary line: `Workspace OK (4/4)` or `Workspace needs attention (3/4 — see above)`.

## Scope

This command does **not** set up the machine (that is `/onboard`). It validates that the current
checkout is ready for agentic workflow.
