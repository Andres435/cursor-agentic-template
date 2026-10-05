<#
.SYNOPSIS
    Verify that a ticket phase actually produced its required artifacts.

.DESCRIPTION
    Mechanical gate for the contract in _shared/ticket-artifacts.md. Replaces
    "the agent should remember to write these files" with a check that fails loudly.

    start-ticket   runs -Phase start     as its last action before the final message.
                   Also checks plan CONTENT, not just existence: a '## Plan Digest'
                   heading (ticket-plan-output.md), an 'Engineering Decisions'
                   heading (engineering-decisions.md -- 'None -- <why>' is valid),
                   and no unresolved placeholder ('TBD', 'resolve during implement').
                   The placeholder check is the point: an open decision is meant to
                   reach the user as a question, not ride into implementation.
                   Also requires a 'Work Plan' heading with numbered steps each
                   tagged [low]|[med]|[high]; any [high] step requires Engineering
                   Decisions to record an architect result (or an explicit
                   'architect skipped: <reason>').
    implement      runs -Phase implement as its first action. Does not re-check plan
                   content: a plan approved before those requirements existed must not
                   retroactively fail here. This is also the LOAD-TIME gate for
                   /complete-task -- see the note on -Phase close below.
    complete-task  runs -Phase close     after the ledger row, NOT at chat start.
                   The close timestamp and the ledger row are written during the
                   command, so running this at load is a guaranteed FAIL.
                   Close accepts blank context percents and fails one outside 0-100.
                   A non-spike close also requires plans/<ticket>-verify.json
                   (Set-VerifyReceipt.ps1): a packet with boolean pass true for each
                   local affected repo. Each of those repos also needs a reviewReady
                   entry (Set-ReviewReady.ps1) with verdict Ready, Ready with fixes, or
                   No change. When the repo path exists, the reviewed work must still be
                   there: the staged diff, or the first-parent commits since the stamp's
                   headSha (a later merge of the base branch is ignored; any other new
                   commit fails). A spike skips both.
                   Optional stackSmoke is Never tested when absent, Tested when passed,
                   Untested latest when stale (or passed fingerprint no longer matches).
                   Not a fail.

    Session timestamps live in the manifest. The retired WI<n>-session.json is still
    accepted as a fallback so tickets started before that change can close.

    Exit code 0 = pass, 1 = fail.

.PARAMETER Ticket
    Work item, with or without the ticket prefix (TICKET-42 or 42).

.PARAMETER Phase
    start | implement | close

.PARAMETER Json
    Emit { phase, ticket, mode, pass, missing[], found[] } instead of human-readable lines.

.EXAMPLE
    .\Assert-TicketArtifacts.ps1 -Ticket TICKET-42 -Phase start

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

. (Join-Path $PSScriptRoot 'lib/ManifestFields.ps1')

# Read ticket prefix from profile.json (default 'WI' for TMO).
# This script does not dot-source _ServiceLauncherLib.ps1.
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
$ScratchDir = Join-Path (Join-Path $RepoRoot 'tmp') 'tickets'

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
        $content = Get-Content -LiteralPath $planFile.FullName -Raw -Encoding UTF8
        if ($content -notmatch '(?im)^\s*#{1,3}\s*Plan Digest\s*$') {
            $missing.Add("$($planFile.Name) -- missing '## Plan Digest' heading (see ticket-plan-output.md)")
            return
        }
        # Engineering Decisions is required before the Work Plan. 'None — <why>' is a
        # valid section; an absent section means the calls were never made explicit.
        if ($content -notmatch '(?im)^\s*#{1,4}\s*(\d+[a-z]?\.?\s*)?Engineering Decisions\s*$') {
            $missing.Add("$($planFile.Name) -- missing 'Engineering Decisions' heading (see engineering-decisions.md; 'None -- <why>' is valid)")
            return
        }
        # An unresolved placeholder is the thing the section exists to prevent: the
        # plan shipped with the call deferred to implementation instead of asked.
        if ($content -match '(?im)\bTBD\b') {
            $missing.Add("$($planFile.Name) -- contains 'TBD'; resolve the open decision or ask the user, do not persist a placeholder")
            return
        }
        if ($content -match '(?im)resolve[d]?\s+during\s+implement') {
            $missing.Add("$($planFile.Name) -- contains 'resolve during implement'; decide it now or ask the user")
            return
        }

        # Work Plan section: heading, numbered steps, difficulty tags, and (for any
        # [high] step) an architect result recorded in Engineering Decisions. This is
        # the model-usage.md/ticket-plan-output.md contract, checked mechanically.
        $planLines = $content -split "\r?\n"
        $workPlanHeadingPattern = '(?i)^\s*#{1,4}\s*(\d+[a-z]?\.?\s*)?Work plan\s*$'
        $workPlanIdx = -1
        for ($li = 0; $li -lt $planLines.Count; $li++) {
            if ($planLines[$li] -match $workPlanHeadingPattern) { $workPlanIdx = $li; break }
        }
        if ($workPlanIdx -lt 0) {
            $missing.Add("$($planFile.Name) -- missing 'Work Plan' heading (see ticket-plan-output.md)")
            return
        }

        $workPlanEndIdx = $planLines.Count
        for ($li = $workPlanIdx + 1; $li -lt $planLines.Count; $li++) {
            if ($planLines[$li] -match '^\s*#{1,4}\s') { $workPlanEndIdx = $li; break }
        }
        $workPlanSection = if ($workPlanEndIdx -gt $workPlanIdx + 1) { $planLines[($workPlanIdx + 1)..($workPlanEndIdx - 1)] } else { @() }

        # Step lines are column-0 numbered lines only; indented sub-lists are notes,
        # not steps, and are not required to carry a tag.
        $stepLines = @($workPlanSection | Where-Object { $_ -match '^\d+\.\s' })
        if ($stepLines.Count -eq 0) {
            $missing.Add("$($planFile.Name) -- 'Work Plan' has no numbered steps")
            return
        }

        $tagPattern = '(?i)^\d+\.\s*[*`_]*\[(low|med|high)\]'
        $untaggedSteps = [System.Collections.Generic.List[string]]::new()
        $hasHighStep = $false
        foreach ($stepLine in $stepLines) {
            if ($stepLine -match $tagPattern) {
                if ($Matches[1] -match '(?i)^high$') { $hasHighStep = $true }
            }
            elseif ($stepLine -match '^(?<n>\d+)\.') {
                $untaggedSteps.Add($Matches['n'])
            }
        }
        if ($untaggedSteps.Count -gt 0) {
            $missing.Add("$($planFile.Name) -- Work Plan step(s) $($untaggedSteps -join ', ') missing a [low]|[med]|[high] tag (see ticket-plan-output.md)")
            return
        }

        if ($hasHighStep) {
            $edHeadingPattern = '(?i)^\s*(#{1,4})\s*(\d+[a-z]?\.?\s*)?Engineering Decisions\s*$'
            $edIdx = -1
            $edLevel = 0
            for ($li = 0; $li -lt $planLines.Count; $li++) {
                if ($planLines[$li] -match $edHeadingPattern) {
                    $edIdx = $li
                    $edLevel = $Matches[1].Length
                    break
                }
            }
            $edEndIdx = $planLines.Count
            if ($edIdx -ge 0) {
                for ($li = $edIdx + 1; $li -lt $planLines.Count; $li++) {
                    if ($planLines[$li] -match '^\s*(#{1,6})\s') {
                        if ($Matches[1].Length -le $edLevel) { $edEndIdx = $li; break }
                    }
                }
            }
            $edSection = if ($edIdx -ge 0 -and $edEndIdx -gt $edIdx + 1) { ($planLines[($edIdx + 1)..($edEndIdx - 1)] -join "`n") } else { '' }
            if ($edSection -notmatch '(?i)\barchitect') {
                $missing.Add("$($planFile.Name) -- has a [high] step but Engineering Decisions records no architect result or 'architect skipped: <reason>' (see skills/architect)")
                return
            }
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
    if ($mode -in @('branch', 'worktree', 'investigate')) {
        $found.Add("$Key-manifest.json (mode: $mode)")
        return
    }
    if ($null -eq $mode) {
        $missing.Add("$Key-manifest.json -- no 'mode' field; must be 'branch', 'worktree', or 'investigate'")
        return
    }
    $missing.Add("$Key-manifest.json -- mode '$mode' is not 'branch', 'worktree', or 'investigate'")
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
    The cached ticket fetch is scratch, not durable config, so it lives in
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
    $missing.Add("tmp/tickets/$name -- cached ticket fetch; later chats reload it instead of re-fetching")
}

<#
    When profile.adrIndex is set, the manifest must carry it so the plan can cite it.
#>
function Test-AdrIndex {
    if (-not $manifest) { return }
    $profileAdr = $null
    $profilePath = Join-Path $Root 'profile.json'
    if (Test-Path -LiteralPath $profilePath) {
        try {
            $prof = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
            if ($prof.PSObject.Properties.Name -contains 'adrIndex') { $profileAdr = [string]$prof.adrIndex }
        } catch { }
    }
    if ([string]::IsNullOrWhiteSpace($profileAdr)) { return }
    $repos = @()
    foreach ($entry in @(Get-ManifestField 'affectedRepos')) {
        if (-not $entry) { continue }
        if ($entry -is [string]) { $repos += $entry; continue }
        if ($entry.PSObject.Properties.Name -contains 'repo') { $repos += $entry.repo }
    }
    if (-not $repos.Count) { return }
    $adr = Get-ManifestField 'adrIndex'
    if ([string]::IsNullOrWhiteSpace([string]$adr)) {
        $missing.Add("$Key-manifest.json -- profile.adrIndex is set, so the manifest adrIndex must be set (see _shared/adr-policy.md)")
        return
    }
    $found.Add("$Key-manifest.json (adrIndex)")
}

<#
    Replaces the per-ticket WI<n>-closeout.md check. A full closeout page is now
    written only when the retrospective earns one, but every closed ticket must
    leave exactly one ledger row -- written by scripts/Update-TicketLedger.ps1.
#>
# Context percents are optional: a measured value, or blank. A blank is honest; an
# invented number is not, so only a present-but-malformed value fails.
function Test-CtxNumber {
    param($Ctx, [string]$Name, [string]$Why)
    if (-not ($Ctx -and ($Ctx.PSObject.Properties.Name -contains $Name)) -or $null -eq $Ctx.$Name) {
        $found.Add("$Key-manifest.json (ctxPct.$Name not recorded)")
        return
    }
    $raw = [string]$Ctx.$Name
    if ($raw -match '^\d+$' -and [int]$raw -le 100) { $found.Add("$Key-manifest.json (ctxPct.$Name)") }
    else { $missing.Add("$Key-manifest.json -- $Why") }
}

function Test-CloseContext {
    $ctx = $null
    if ($manifest -and ($manifest.PSObject.Properties.Name -contains 'ctxPct')) {
        $ctx = $manifest.ctxPct
    }
    foreach ($name in @('start', 'review', 'close')) {
        Test-CtxNumber -Ctx $ctx -Name $name -Why "ctxPct.$name must be 0-100 when present. Re-run Set-TicketCtxPct.ps1 -Phase $name without -Percent to use the measured value."
    }
}

function Get-CloseRepoNames {
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @(Get-ManifestField 'affectedRepos')) {
        if (-not $entry) { continue }
        if ($entry -is [string]) {
            $list.Add([pscustomobject]@{ repo = [string]$entry; path = $null })
            continue
        }
        $props = @($entry.PSObject.Properties.Name)
        if ($props -notcontains 'repo') { continue }
        $name = [string]$entry.repo
        if (-not $name) { continue }
        if (($props -contains 'local') -and ($null -ne $entry.local) -and -not [bool]$entry.local) { continue }
        $path = $null
        if (($props -contains 'path') -and $entry.path) { $path = [string]$entry.path }
        $list.Add([pscustomobject]@{ repo = $name; path = $path })
    }
    return @($list)
}

# Real closes resolve repo paths. Fixture runs pass -Root and only compare when the
# manifest entry itself names a path, so a missing checkout stays a JSON check.
function Get-ResolvedRepoPaths {
    $map = @{}
    if ($Root) { return $map }
    $resolveScript = Join-Path $PSScriptRoot 'Resolve-TicketRoot.ps1'
    if (-not (Test-Path -LiteralPath $resolveScript)) { return $map }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $json = & $resolveScript -Ticket $Key -Json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $json) { return $map }
        $resolved = $json | ConvertFrom-Json
        foreach ($r in @($resolved.repos)) {
            if (-not $r) { continue }
            $names = @($r.PSObject.Properties.Name)
            $exists = ($names -contains 'exists') -and [bool]$r.exists
            if ($exists -and $r.path) { $map[[string]$r.repo] = [string]$r.path }
        }
    }
    catch { }
    finally { $ErrorActionPreference = $prev }
    return $map
}

function Test-VerifyReceipt {
    $name = "$Key-verify.json"
    $path = Join-Path $PlansDir $name
    if (-not (Test-Path -LiteralPath $path)) {
        $missing.Add("$name -- verify receipt missing; run Set-VerifyReceipt.ps1 per repo after verify-repo")
        return
    }
    try {
        $doc = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        $missing.Add("$name -- present but not valid JSON: $($_.Exception.Message)")
        return
    }
    $packets = @($doc | Where-Object { $_ })
    if ($packets.Count -eq 0) {
        $missing.Add("$name -- verify-repo receipt has no packets")
        return
    }
    $byRepo = @{}
    $coversAll = $false
    foreach ($packet in $packets) {
        $names = @($packet.PSObject.Properties.Name)
        $label = if ($names -contains 'repo' -and $packet.repo) { [string]$packet.repo } else { '(all repos)' }
        # A JSON string "false" is truthy in PowerShell, so only a real boolean counts.
        $ok = ($names -contains 'pass') -and ($packet.pass -is [bool]) -and $packet.pass
        if (-not $ok) {
            $missing.Add("$name -- $label pass must be boolean true")
            continue
        }
        if ($label -eq '(all repos)') { $coversAll = $true } else { $byRepo[$label] = $packet }
        if (($names -contains 'tests') -and ([string]$packet.tests -eq 'not-run')) {
            $why = if ($names -contains 'reason') { [string]$packet.reason } else { '' }
            $found.Add("$name ($label tests not run: $why)")
        }
    }
    if (-not $coversAll) {
        foreach ($repo in @(Get-CloseRepoNames)) {
            if (-not $byRepo.ContainsKey($repo.repo)) {
                $missing.Add("$name -- no packet for $($repo.repo)")
            }
        }
    }
    $found.Add($name)
}

function Test-ReviewFingerprints {
    $repos = @(Get-CloseRepoNames)
    $resolved = Get-ResolvedRepoPaths
    $stampRepos = $null
    $stampMode = 'staged'
    if ($manifest -and ($manifest.PSObject.Properties.Name -contains 'reviewReady') -and $manifest.reviewReady) {
        $stamp = $manifest.reviewReady
        if ($stamp.PSObject.Properties.Name -contains 'repos') { $stampRepos = $stamp.repos }
        if (($stamp.PSObject.Properties.Name -contains 'mode') -and $stamp.mode) { $stampMode = [string]$stamp.mode }
    }
    foreach ($repo in $repos) {
        $label = "$Key-manifest.json -- reviewReady.repos.$($repo.repo)"
        $entry = $null
        if ($stampRepos -and ($stampRepos.PSObject.Properties.Name -contains $repo.repo)) {
            $entry = $stampRepos.($repo.repo)
        }
        if (-not $entry) {
            $missing.Add("$label -- no review stamp; run Set-ReviewReady.ps1 after review-diff")
            continue
        }
        $verdict = Get-StampEntryValue $entry 'verdict'
        if (-not (Test-ReviewVerdict $verdict)) {
            $missing.Add("$label.verdict is '$verdict' -- needs Ready, Ready with fixes, or No change")
            continue
        }
        $mode = Get-StampEntryValue $entry 'mode'
        if (-not $mode) { $mode = $stampMode }
        $noChange = ($verdict.Replace('*', '').Trim() -eq 'No change')
        if ($noChange -or $mode -eq 'pre-merge') {
            if ((Get-StampEntryValue $entry 'headSha') -notmatch '^[0-9a-fA-F]{40}$') {
                $missing.Add("$label.headSha must name the reviewed commit")
                continue
            }
        } else {
            $fpNorm = (Get-StampEntryValue $entry 'fingerprint').ToLowerInvariant()
            if ($fpNorm -notmatch '^[0-9a-f]{64}$' -or $fpNorm -eq $script:EmptyDiffFingerprint) {
                $missing.Add("$label.fingerprint must be a non-empty review hash")
                continue
            }
        }
        $path = $repo.path
        if (-not $path -and $resolved.ContainsKey($repo.repo)) { $path = $resolved[$repo.repo] }
        if (-not $path -or -not (Test-Path -LiteralPath $path)) {
            $found.Add("$Key-manifest.json (reviewReady.repos.$($repo.repo): $verdict)")
            continue
        }
        $check = Test-ReviewedWorkPresent -RepoPath $path -Entry $entry -StampMode $stampMode
        if (-not $check.ok) {
            $missing.Add("$label -- $($check.reason); re-review, then Set-ReviewReady.ps1")
            continue
        }
        $found.Add("$Key-manifest.json (reviewReady.repos.$($repo.repo): $verdict, $($check.reason))")
    }
}

function Test-CloseWork {
    if ($workType -eq 'spike') { return }
    Test-VerifyReceipt
    Test-ReviewFingerprints
}

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
        Test-CloseContext
        Test-LedgerRow
        Test-CloseWork
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
        Write-Host "       Contract: _shared/ticket-artifacts.md" -ForegroundColor DarkGray
    }
}

if (-not $pass) { exit 1 }
exit 0
