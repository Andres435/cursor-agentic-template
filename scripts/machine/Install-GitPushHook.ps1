<#
.SYNOPSIS
    Point this repo's git pre-push at Assert-AgenticFlow.ps1 (fail-closed).

.DESCRIPTION
    Sets local core.hooksPath to hooks/git-hooks. After this, `git push` in
    this clone runs hooks/git-push-agentic-flow.js --git-hook, which invokes
    Assert-AgenticFlow.ps1. Windows work machines use powershell.exe; machines
    with pwsh use that. `git push --no-verify` skips the hook — do not use it.

    Safe to re-run. Does not change global git config.
#>
[CmdletBinding()]
param([switch]$WhatIf)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$hookFile = Join-Path $RepoRoot 'hooks' 'git-hooks' 'pre-push'
if (-not (Test-Path -LiteralPath $hookFile)) {
    throw "Missing $hookFile — pull the latest workspace."
}

if ($WhatIf) {
    Write-Host "[WhatIf] Would set core.hooksPath=hooks/git-hooks in $RepoRoot" -ForegroundColor DarkGray
    exit 0
}

git -C $RepoRoot config core.hooksPath 'hooks/git-hooks'
if ($LASTEXITCODE -ne 0) { throw "git config core.hooksPath failed" }
Write-Host "git push now runs Assert-AgenticFlow.ps1 (fail-closed)." -ForegroundColor Green
