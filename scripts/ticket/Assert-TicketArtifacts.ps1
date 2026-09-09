<#
.SYNOPSIS
    Verify that a ticket phase actually produced its required artifacts.

.DESCRIPTION
    Mechanical gate for the contract in _shared/ticket-artifacts.md. Replaces
    "the agent should remember to write these files" with a check that fails loudly.

    start-ticket   runs -Phase start     as its last action before the final message.
                   Also checks the plan file opens with a '## Plan Digest' heading
                   (see ticket-plan-output.md) -- content, not just existence.
    implement      runs -Phase implement as its first action. Does not re-check the
                   digest: a plan approved before that requirement existed must not
                   retroactively fail here. This is also the LOAD-TIME gate for
                   /complete-task -- see the note on -Phase close below.
    complete-task  runs -Phase close     before the retrospective, NOT at chat start.
                   The close timestamp and the ledger row are written during the
                   command, so running this at load is a guaranteed FAIL.

    Session timestamps live in the manifest. The retired WI<n>-session.json is still
    accepted as a fallback so tickets started before that change can close.

    Exit code 0 = pass, 1 = fail.

.PARAMETER Ticket
    Work item, with or without the WI prefix (WI21588 or 21588).

.PARAMETER Phase
    start | implement | close

.PARAMETER Json
    Emit { phase, ticket, mode, pass, missing[], found[] } instead of human-readable lines.

.EXAMPLE
    .\Assert-TicketArtifacts.ps1 -Ticket WI21588 -Phase start

.EXAMPLE
    .\Assert-TicketArtifacts.ps1 -Ticket 22132 -Phase implement -Json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Ticket,

    [Parameter(Mandatory)]
    [ValidateSet('start', 'implement', 'close')]
    [string]$Phase,

    # Override the repo root (for testing against fixtures).
    [string]$Root,

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Read ticket prefix from profile.json (default 'WI' for TMO).
function Get-TicketPrefix {
    $p = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'profile.json'
    if (Test-Path -LiteralPath $p) {
        try { $c = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
              if ($c.ticketPrefix) { return [string]$c.ticketPrefix } } catch { }
    }
    return 'WI'
}
$_prefix = Get-TicketPrefix

$digits = $Ticket -replace '[^\d]', ''
if (-not $digits) { throw "Could not read a work item number from '$Ticket'." }
# Honor an explicit prefix on the argument (CI fixtures are WI00001 even when
# profile.ticketPrefix is TICKET-). Bare digits use the profile prefix.
if ($Ticket -match '^(?<pre>[A-Za-z]+-?)\d') {
    $Key = $Matches['pre'] + $digits
} else {
    $Key = $_prefix + $digits
}
$RepoRoot = if ($Root) { $Root } else { Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
$PlansDir = Join-Path $RepoRoot 'plans'
$ScratchDir = Join-Path $RepoRoot 'tmp' 'tickets'

$missing = [System.Collections.Generic.List[string]]::new()
$found = [System.Collections.Generic.List[string]]::new()

function Test-Artifact {
    param([string]$Name, [string]$Why)

    $path = Join-Path $PlansDir $Name
    if (Test-Path -LiteralPath $path) {
        $found.Add($Name)
        return $true
    }
    $missing.Add("$Name -- $Why")
    return $false
}

# The plan file is named from the manifest workType, and the mode decides which
# artifacts apply at all, so resolve the manifest first.
$manifest = $null
$workType = $null
$mode = $null
$manifestPath = Join-Path $PlansDir "$Key-manifest.json"
if (Test-Path -LiteralPath $manifestPath) {
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $names = $manifest.PSObject.Properties.Name
        if ($names -contains 'workType') { $workType = $manifest.workType }
        if ($names -contains 'mode') { $mode = $manifest.mode }
    }
    catch {
        $missing.Add("$Key-manifest.json -- present but not valid JSON: $($_.Exception.Message)")
    }
}

function Get-ManifestField {
    param([string]$Name)
    if (-not $manifest) { return $null }
    if (-not ($manifest.PSObject.Properties.Name -contains $Name)) { return $null }
    return $manifest.$Name
}

function Test-PlanFile {
    # Prefer the workType-derived name; accept any WI<n>-*-plan.md so a spike/refactor
    # naming variation does not produce a false failure.
    param([switch]$CheckDigest)

    $expected = if ($workType) { "$Key-$workType-plan.md" } else { "$Key-<type>-plan.md" }
    $planFiles = @(Get-ChildItem -LiteralPath $PlansDir -Filter "$Key-*-plan.md" -File -ErrorAction SilentlyContinue)
    if ($planFiles.Count -eq 0) {
        $missing.Add("$expected -- approved plan; implement has nothing to follow without it")
        return
    }
    $planFile = $planFiles[0]

    # Digest presence is only checked when start-ticket verifies its own output (-Phase
    # start). implement/close load whatever plan already exists -- a plan approved before
    # this requirement existed must not retroactively fail those phases.
    if ($CheckDigest) {
        $content = Get-Content -LiteralPath $planFile.FullName -Raw
        if ($content -notmatch '(?im)^\s*#{1,3}\s*Plan Digest\s*$') {
            $missing.Add("$($planFile.Name) -- missing '## Plan Digest' heading (see ticket-plan-output.md)")
            return
        }
    }
    $found.Add($planFile.Name)
}

# Existence and mode in one entry, so a pass reports one line per artifact.
function Test-Manifest {
    param([string]$Why)

    if (-not (Test-Path -LiteralPath $manifestPath)) {
        $missing.Add("$Key-manifest.json -- $Why")
        return
    }
    if ($mode -in @('branch', 'worktree')) {
        $found.Add("$Key-manifest.json (mode: $mode)")
        return
    }
    if ($null -eq $mode) {
        $missing.Add("$Key-manifest.json -- no 'mode' field; must be 'branch' or 'worktree' so later chats know where to work")
        return
    }
    $missing.Add("$Key-manifest.json -- mode '$mode' is not 'branch' or 'worktree'")
}

<#
    Session timestamps moved from WI<n>-session.json into the manifest. Read the
    manifest first and fall back to the retired file, so a ticket started before
    the change can still close.
#>
function Get-SessionSource {
    $names = @()
    if ($manifest) { $names = $manifest.PSObject.Properties.Name }
    foreach ($field in @('startedAtUtc', 'completedAtUtc', 'reopenedAtUtc', 'reclosedAtUtc')) {
        if ($names -contains $field) {
            return [pscustomobject]@{ Data = $manifest; Label = "$Key-manifest.json" }
        }
    }

    $legacy = Join-Path $PlansDir "$Key-session.json"
    if (Test-Path -LiteralPath $legacy) {
        try {
            return [pscustomobject]@{
                Data  = (Get-Content -LiteralPath $legacy -Raw | ConvertFrom-Json)
                Label = "$Key-session.json (legacy)"
            }
        }
        catch {
            $missing.Add("$Key-session.json -- present but not valid JSON: $($_.Exception.Message)")
            return $null
        }
    }
    return $null
}

function Test-TimestampField {
    param([string[]]$Fields, [string]$Why)

    $src = Get-SessionSource
    if (-not $src) {
        $missing.Add("$Key-manifest.json -- $Why")
        return
    }
    $names = $src.Data.PSObject.Properties.Name
    $set = @($Fields | Where-Object {
        ($names -contains $_) -and -not [string]::IsNullOrWhiteSpace([string]$src.Data.$_)
    })
    if ($set.Count) {
        $found.Add("$($src.Label) ($($set -join ', '))")
    }
    else {
        $missing.Add("$($src.Label) -- $Why")
    }
}

<#
    The cached ADO fetch is scratch, not durable config, so it lives in
    tmp/tickets/. The old plans/ location is still accepted for in-flight tickets.
#>
function Test-WorkItemCache {
    $name = "$Key-workitem.json"
    foreach ($dir in @($ScratchDir, $PlansDir)) {
        $path = Join-Path $dir $name
        if (Test-Path -LiteralPath $path) {
            $found.Add((Join-Path (Split-Path $dir -Leaf) $name))
            return
        }
    }
    $missing.Add("tmp/tickets/$name -- cached ADO fetch; later chats reload it instead of re-fetching")
}

<#
    adrIndex is contracted by the router whenever TmoPro is in scope, but was
    filled in only 1 of 13 real manifests -- the plan chat then never sees the ADR
    corpus it is supposed to cite. Checked, not restated.
#>
function Test-AdrIndex {
    if (-not $manifest) { return }
    $repos = @()
    foreach ($entry in @(Get-ManifestField 'affectedRepos')) {
        if (-not $entry) { continue }
        if ($entry -is [string]) { $repos += $entry; continue }
        if ($entry.PSObject.Properties.Name -contains 'repo') { $repos += $entry.repo }
    }
    if ($repos -notcontains 'TmoPro') { return }

    $adr = Get-ManifestField 'adrIndex'
    if ([string]::IsNullOrWhiteSpace([string]$adr)) {
        $missing.Add("$Key-manifest.json -- TmoPro is in affectedRepos, so adrIndex must be set (see _shared/adr-policy.md)")
        return
    }
    $found.Add("$Key-manifest.json (adrIndex)")
}

<#
    Replaces the per-ticket WI<n>-closeout.md check. A full closeout page is now
    written only when the retrospective earns one, but every closed ticket must
    leave exactly one ledger row -- written by scripts/Update-TicketLedger.ps1.
#>
function Test-LedgerRow {
    $ledger = Join-Path $PlansDir 'ticket-ledger.md'
    if (-not (Test-Path -LiteralPath $ledger)) {
        $missing.Add("plans/ticket-ledger.md -- run scripts/Update-TicketLedger.ps1 -Ticket $Key ...")
        return
    }
    $rows = @(Get-Content -LiteralPath $ledger | Where-Object { $_ -match "^\|\s*$Key\s*\|" })
    if ($rows.Count -eq 1) {
        $found.Add("plans/ticket-ledger.md ($Key row)")
    }
    elseif ($rows.Count -eq 0) {
        $missing.Add("plans/ticket-ledger.md -- no row for $Key; run scripts/Update-TicketLedger.ps1 -Ticket $Key ...")
    }
    else {
        $missing.Add("plans/ticket-ledger.md -- $($rows.Count) rows for $Key; expected exactly one")
    }
}

switch ($Phase) {
    'start' {
        Test-Manifest 'routing table for every later chat (must include ticket object with title/adoType/state/area/priority)'
        Test-AdrIndex
        Test-TimestampField -Fields @('startedAtUtc') -Why 'startedAtUtc is null or absent; complete-task cannot compute hours without it'
        Test-PlanFile -CheckDigest
    }
    'implement' {
        Test-Manifest 'run /start-ticket first, or re-run its router step'
        Test-PlanFile
    }
    'close' {
        Test-Artifact "$Key-manifest.json" 'drives verify/review fan-out' | Out-Null
        Test-TimestampField -Fields @('completedAtUtc', 'reclosedAtUtc') -Why 'no completedAtUtc or reclosedAtUtc set'
        Test-LedgerRow
    }
}

$pass = $missing.Count -eq 0

if ($Json) {
    [pscustomobject]@{
        phase   = $Phase
        ticket  = $Key
        mode    = $mode
        pass    = $pass
        missing = @($missing)
        found   = @($found)
    } | ConvertTo-Json -Depth 4
}
else {
    if ($pass) {
        Write-Host "[PASS] $Key $Phase artifacts complete ($($found.Count) checked)." -ForegroundColor Green
        foreach ($f in $found) { Write-Host "       $f" }
    }
    else {
        Write-Host "[FAIL] $Key $Phase is incomplete -- $($missing.Count) artifact(s) missing:" -ForegroundColor Red
        foreach ($m in $missing) { Write-Host "       $m" -ForegroundColor Red }
        Write-Host "       Contract: .cursor/_shared/ticket-artifacts.md" -ForegroundColor DarkGray
    }
}

if (-not $pass) { exit 1 }
exit 0
