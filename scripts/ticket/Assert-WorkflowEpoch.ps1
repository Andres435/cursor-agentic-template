#Requires -Version 7
<#
.SYNOPSIS
    Report the workflow epoch and fail only on a malformed ledger row.

.DESCRIPTION
    The epoch id is computed from the watched workflow contract (lib/WorkflowEpoch.ps1),
    so a contract edit starts a new epoch by itself. There is no timer, no stamp file,
    and no -Accept step. This script:

      - fails a local ledger row that has no close date (the ledger is user-local; a
        fresh clone and CI have none, which passes);
      - prints [INFO] when the newest close ran under an older epoch;
      - prints [INFO] re-rate when the current epoch has reached epochRerateAfter
        closes (profile.json, default 3) without a "Rated: <id>" line in the ledger.
        Record a rating with Update-TicketLedger.ps1 -MarkRated.

.PARAMETER Root
    Repo root. Defaults to the workflow repo (two levels up from scripts/ticket).
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path (Join-Path $PSScriptRoot 'lib') 'WorkflowEpoch.ps1')

function Test-EpochLedgerRows {
    param([string]$Root)
    $problems = [System.Collections.Generic.List[string]]::new()
    $ledgerPath = Join-Path $Root 'plans/ticket-ledger.md'
    if (-not (Test-Path -LiteralPath $ledgerPath)) { return ,$problems }
    foreach ($line in (Get-Content -LiteralPath $ledgerPath -Encoding UTF8)) {
        if ($line -notmatch '^\|\s*([A-Za-z#][A-Za-z0-9_-]*\d+)') { continue }
        $cells = @(($line.Trim() -replace '^\|', '' -replace '\|$', '') -split '\|' | ForEach-Object { $_.Trim() })
        $closed = if ($cells.Count -gt 2) { $cells[2] } else { '' }
        if ($closed -notmatch '^\d{4}-\d{2}-\d{2}$') {
            $problems.Add("ledger row $($cells[0]) has no close date")
        }
    }
    return ,$problems
}

if ($MyInvocation.InvocationName -ne '.') {
    $problems = Test-EpochLedgerRows -Root $Root
    foreach ($problem in $problems) {
        Write-Host "[FAIL] $problem -- fix it with scripts/ticket/Update-TicketLedger.ps1 (never hand-edit)"
    }

    $status = Get-EpochStatus -Root $Root
    if (-not $status.epoch) {
        Write-Host '[INFO] workflow epoch: not a git checkout, no epoch id'
    } else {
        Write-Host "[INFO] workflow epoch $($status.epoch): $($status.closes) close(s), re-rate after $($status.threshold)"
        if ($status.previous -and $status.closes -eq 0) {
            Write-Host "[INFO] new workflow epoch $($status.epoch) (last close ran under $($status.previous))"
        }
        if ($status.due) {
            Write-Host "[INFO] re-rate: epoch $($status.epoch) has $($status.closes) closes and no rating -- rate the workflow, then run Update-TicketLedger.ps1 -MarkRated"
        }
    }

    if ($problems.Count) { exit 1 }
    Write-Host '[PASS] workflow epoch'
    exit 0
}
