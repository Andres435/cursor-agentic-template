<#
.SYNOPSIS
    Stamp optional stackSmoke (start-stack runtime pass) onto a ticket manifest.

.DESCRIPTION
    Called after a /start-stack smoke pass (only when the user confirms it passed
    or failed), during /complete-task when the user skips, or after PR-comment
    logic changes that invalidate a prior pass. Close does not require this field.

    Status:
      passed  — Tested (flow worked on the local stack)
      failed  — stack was up but the flow did not
      skipped — user declined the optional pass
      stale   — Untested latest changes (prior pass/fail, then logic changed)

    Absence of the field is Never tested. passed/failed also store a work-diff
    fingerprint so /complete-task can detect later commits without an explicit stale stamp.

.PARAMETER Ticket
    Work item, with or without the ticket prefix.

.PARAMETER Status
    passed | failed | skipped | stale

.PARAMETER Notes
    One-line what was exercised, why it was skipped, or what logic changed.

.PARAMETER Preset
    Stack preset if known (for example web or api).

.PARAMETER RepoPaths
    JSON object mapping repo name to working-tree path. Overrides
    Resolve-TicketRoot (tests, or when resolution fails).

.PARAMETER Root
    Override the workflow repo root (tests).

.EXAMPLE
    .\Set-StackSmoke.ps1 -Ticket TICKET-42 -Status passed -Notes "Valid reset link showed form." -Preset web

.EXAMPLE
    .\Set-StackSmoke.ps1 -Ticket TICKET-42 -Status stale -Notes "PR comment changed link expiry."
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ticket,
    [Parameter(Mandatory)][ValidateSet('passed', 'failed', 'skipped', 'stale')][string]$Status,
    [string]$Notes,
    [string]$Preset,
    [string]$RepoPaths,
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path (Join-Path $PSScriptRoot 'lib') 'ManifestFields.ps1')

$Key = Get-TicketKeyFromRaw -Ticket $Ticket
$RepoRoot = if ($Root) { $Root } else { Get-CursorRepoRoot -FromScriptRoot $PSScriptRoot }
$manifestPath = Get-TicketManifestFile -RepoRoot $RepoRoot -TicketKey $Key
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Manifest not found: $manifestPath"
}

$existing = $null
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.PSObject.Properties.Name -contains 'stackSmoke') { $existing = $manifest.stackSmoke }

$pathMap = @{}
if ($RepoPaths) {
    foreach ($p in ($RepoPaths | ConvertFrom-Json).PSObject.Properties) { $pathMap[$p.Name] = [string]$p.Value }
}
if (-not $pathMap.Count) {
    $resolveScript = Join-Path $PSScriptRoot 'Resolve-TicketRoot.ps1'
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $resolvedJson = & $resolveScript -Ticket $Key -Json 2>$null
        if ($LASTEXITCODE -eq 0 -and $resolvedJson) {
            $resolved = $resolvedJson | ConvertFrom-Json
            if ($resolved.repos) {
                foreach ($r in @($resolved.repos)) {
                    if ($r.repo -and $r.path) { $pathMap[[string]$r.repo] = [string]$r.path }
                }
            }
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

$stamp = [pscustomobject]@{
    status = $Status
    atUtc  = [DateTime]::UtcNow.ToString('o')
}

if ($Status -in @('passed', 'failed')) {
    $fp = Get-StackSmokeWorkFingerprint -RepoPaths $pathMap
    if ($fp) {
        $stamp | Add-Member -NotePropertyName fingerprint -NotePropertyValue $fp
        $stamp | Add-Member -NotePropertyName fpVersion -NotePropertyValue 2
    }
    $stamp | Add-Member -NotePropertyName lastStatus -NotePropertyValue $Status
}
elseif ($Status -eq 'stale') {
    $prior = 'passed'
    if ($existing -and ($existing.PSObject.Properties.Name -contains 'status') -and $existing.status -in @('passed', 'failed')) {
        $prior = [string]$existing.status
    }
    elseif ($existing -and ($existing.PSObject.Properties.Name -contains 'lastStatus') -and $existing.lastStatus) {
        $prior = [string]$existing.lastStatus
    }
    $stamp | Add-Member -NotePropertyName lastStatus -NotePropertyValue $prior
    $oldFp = $null
    if ($existing -and ($existing.PSObject.Properties.Name -contains 'fingerprint')) {
        $oldFp = [string]$existing.fingerprint
    }
    if ($oldFp) {
        $stamp | Add-Member -NotePropertyName fingerprint -NotePropertyValue $oldFp
        $oldVersion = if ($existing.PSObject.Properties.Name -contains 'fpVersion') { $existing.fpVersion } else { $null }
        if ($oldVersion) { $stamp | Add-Member -NotePropertyName fpVersion -NotePropertyValue $oldVersion }
    }
}

if ($Notes) { $stamp | Add-Member -NotePropertyName notes -NotePropertyValue $Notes }
if ($Preset) {
    $stamp | Add-Member -NotePropertyName preset -NotePropertyValue $Preset
}
elseif ($existing -and ($existing.PSObject.Properties.Name -contains 'preset') -and $existing.preset) {
    $stamp | Add-Member -NotePropertyName preset -NotePropertyValue ([string]$existing.preset)
}

Merge-TicketManifestFields -ManifestPath $manifestPath -Patch @{ stackSmoke = $stamp }
Write-Host "Wrote stackSmoke ($Status) on $manifestPath" -ForegroundColor Green
