#Requires -Version 7
<#
.SYNOPSIS
    Workflow epoch: an id computed from the watched workflow contract, plus the
    re-rate trigger. Dot-sourced by Assert-WorkflowEpoch.ps1 and Update-TicketLedger.ps1.

.DESCRIPTION
    The epoch exists so ledger rows are compared only with rows closed under the same
    contract, and so the workflow gets re-rated when that contract changes. Nothing
    here runs on a clock:

      - The id is a hash of the watched paths' git tree at HEAD. Editing any of them
        makes a new id; there is no stamp file and no -Accept commit.
      - Each ledger row records the id it closed under (Epoch column).
      - Re-rate is due once the current epoch has epochRerateAfter closes
        (profile.json, default 3) and the ledger has no "Rated: <id>" line for it.
#>

Set-StrictMode -Version Latest

$script:WorkflowEpochWatch = @(
    'skills/start-ticket/playbooks/start-ticket.md'
    'skills/engineering-mode/SKILL.md'
    'skills/implement/playbooks/implement.md'
    'skills/complete-task/'
    'scripts/ticket/Assert-TicketArtifacts.ps1'
    'scripts/ticket/Update-TicketLedger.ps1'
    'scripts/ticket/Assert-AgenticFlow.ps1'
    '_shared/ticket-artifacts.md'
    '_shared/model-routing.md'
    'profile.json'
    'USER-MANUAL.md'
)

# Short hash of the watched contract at HEAD, or '' when $Root is not a git checkout
# (an installed plugin copy has no history; its rows simply carry no epoch).
function Get-WorkflowEpochId {
    param([Parameter(Mandatory)][string]$Root)
    $spec = @($script:WorkflowEpochWatch | ForEach-Object { $_.TrimEnd('/') })
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $tree = & git -C $Root ls-tree -r HEAD -- @spec 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $tree) { return '' }
    } finally {
        $ErrorActionPreference = $prev
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes((@($tree) -join "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $hex = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
    return $hex.Substring(0, 8)
}

function Get-EpochRerateAfter {
    param([Parameter(Mandatory)][string]$Root)
    $p = Join-Path $Root 'profile.json'
    if (Test-Path -LiteralPath $p) {
        try {
            $prof = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
            if ($prof.PSObject.Properties.Name -contains 'epochRerateAfter') { return [int]$prof.epochRerateAfter }
        } catch { }
    }
    return 3
}

# Epoch column index in plans/ticket-ledger.md rows (0-based, after Lanes).
$script:EpochLedgerCell = 14

function Get-LedgerRatedEpochs {
    param([Parameter(Mandatory)][string]$LedgerPath)
    if (-not (Test-Path -LiteralPath $LedgerPath)) { return @() }
    $line = Get-Content -LiteralPath $LedgerPath -Encoding UTF8 | Where-Object { $_ -match '^Rated:' } | Select-Object -First 1
    if (-not $line) { return @() }
    return @(($line -replace '^Rated:\s*', '') -split '[,\s]+' | Where-Object { $_ -match '^[0-9a-f]{8}$' })
}

<#
    Where the ledger stands against the current epoch:
      epoch     current id ('' outside a git checkout)
      closes    ledger rows closed under it
      previous  epoch of the newest row that ran under a different id, or ''
      rated     whether "Rated:" lists the current id
      due       closes >= threshold and not rated
#>
function Get-EpochStatus {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$LedgerPath = (Join-Path (Join-Path $Root 'plans') 'ticket-ledger.md')
    )
    $epoch = Get-WorkflowEpochId -Root $Root
    $threshold = Get-EpochRerateAfter -Root $Root
    $closes = 0
    $previous = ''
    if (Test-Path -LiteralPath $LedgerPath) {
        foreach ($line in (Get-Content -LiteralPath $LedgerPath -Encoding UTF8)) {
            if ($line -notmatch '^\|\s*([A-Za-z#][A-Za-z0-9_-]*\d+)') { continue }
            $cells = @(($line.Trim() -replace '^\|', '' -replace '\|$', '') -split '\|' | ForEach-Object { $_.Trim() })
            $rowEpoch = if ($cells.Count -gt $script:EpochLedgerCell) { $cells[$script:EpochLedgerCell] } else { '' }
            if (-not $rowEpoch) { continue }
            if ($epoch -and $rowEpoch -eq $epoch) { $closes++ } else { $previous = $rowEpoch }
        }
    }
    $rated = $epoch -and ((Get-LedgerRatedEpochs -LedgerPath $LedgerPath) -contains $epoch)
    return [pscustomobject]@{
        epoch     = $epoch
        closes    = $closes
        threshold = $threshold
        previous  = $previous
        rated     = [bool]$rated
        due       = [bool]($epoch -and -not $rated -and $closes -ge $threshold)
    }
}
