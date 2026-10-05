<#
.SYNOPSIS
    Stamp reviewReady (verdict + staged fingerprint) onto a ticket manifest.

.DESCRIPTION
    Called at the end of /review-changes, and by /complete-task after its own
    review-diff. Per repo it records the verdict, mode, HEAD (headSha), and the
    SHA256 of the canonical staged diff (fpVersion 2). Entries are upserted, so
    stamping one repo keeps the others. /complete-task skips a duplicate
    review-diff while the verdict is Ready on the same staged set, and
    Assert-TicketArtifacts -Phase close checks the committed work still matches.

.PARAMETER Ticket
    Work item, with or without the ticket prefix.

.PARAMETER Mode
    staged (working-tree /review-changes) or pre-merge (work already committed;
    records headSha, no fingerprint). Complete-task only skips on staged.

.PARAMETER Verdicts
    JSON object mapping repo name to verdict, e.g. '{"app":"Ready"}'.
    Verdicts: Ready, Ready with fixes, Not ready, or No change (an affected repo
    with nothing to review; refused when something is staged).
    When omitted, -Verdict is applied to every resolved affected repo.

.PARAMETER Verdict
    Single verdict applied to all affected repos when -Verdicts is omitted.

.PARAMETER RepoPaths
    JSON object mapping repo name to its working-tree path. Overrides
    Resolve-TicketRoot for those repos (tests, or when resolution fails).

.PARAMETER Root
    Override the workflow repo root (tests).

.EXAMPLE
    .\Set-ReviewReady.ps1 -Ticket TICKET-42 -Mode staged -Verdicts '{"app":"Ready"}'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ticket,
    [Parameter(Mandatory)][ValidateSet('staged', 'pre-merge')][string]$Mode,
    [string]$Verdicts,
    [string]$Verdict,
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

$verdictMap = @{}
if ($Verdicts) {
    $parsed = $Verdicts | ConvertFrom-Json
    foreach ($p in $parsed.PSObject.Properties) {
        $verdictMap[$p.Name] = [string]$p.Value
    }
}

$resolveScript = Join-Path $PSScriptRoot 'Resolve-TicketRoot.ps1'
$resolved = $null
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $resolvedJson = & $resolveScript -Ticket $Key -Json 2>$null
    if ($LASTEXITCODE -eq 0 -and $resolvedJson) {
        $resolved = $resolvedJson | ConvertFrom-Json
    }
} finally {
    $ErrorActionPreference = $prevEap
}

$repoEntries = @()
if ($resolved -and $resolved.repos) { $repoEntries = @($resolved.repos) }

if (-not $verdictMap.Count) {
    if (-not $Verdict) { throw "Pass -Verdicts JSON or -Verdict." }
    if (-not $repoEntries.Count) { throw "No affected repos resolved for $Key - pass -Verdicts." }
    foreach ($r in $repoEntries) { $verdictMap[$r.repo] = $Verdict }
}

$pathMap = @{}
if ($RepoPaths) {
    foreach ($p in ($RepoPaths | ConvertFrom-Json).PSObject.Properties) { $pathMap[$p.Name] = [string]$p.Value }
}

# Upsert: a later stamp (for example complete-task re-reviewing one repo) keeps the other
# repos' entries from /review-changes.
$existing = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$reposObj = New-Object PSObject
if (($existing.PSObject.Properties.Name -contains 'reviewReady') -and $existing.reviewReady -and
    ($existing.reviewReady.PSObject.Properties.Name -contains 'repos') -and $existing.reviewReady.repos) {
    $oldMode = Get-StampEntryValue $existing.reviewReady 'mode'
    foreach ($p in $existing.reviewReady.repos.PSObject.Properties) {
        $old = $p.Value
        # Older entries took their mode from the stamp; pin it so a new top-level mode cannot change them.
        if ($old -and $oldMode -and -not (Get-StampEntryValue $old 'mode')) {
            $old | Add-Member -NotePropertyName 'mode' -NotePropertyValue $oldMode -Force
        }
        $reposObj | Add-Member -NotePropertyName $p.Name -NotePropertyValue $old
    }
}

foreach ($name in ($verdictMap.Keys | Sort-Object)) {
    $path = $pathMap[$name]
    if (-not $path) {
        $hit = $repoEntries | Where-Object { $_.repo -eq $name } | Select-Object -First 1
        if ($hit) { $path = [string]$hit.path }
    }
    $where = if ($path) { $path } else { 'an unresolved path' }
    $entryVerdict = [string]$verdictMap[$name]
    $noChange = ($entryVerdict.Replace('*', '').Trim() -ieq 'No change')
    $fp = if ($path) { Get-StagedDiffFingerprint -RepoPath $path } else { $null }
    $headSha = if ($path) { Get-GitHeadSha -RepoPath $path } else { $null }
    if ($noChange) {
        if ($fp) { throw "$name has staged changes ($where). 'No change' is only for a repo with nothing to review." }
        if (-not $headSha) { throw "No HEAD in $name ($where). 'No change' needs a resolvable repo." }
    } elseif ($Mode -eq 'staged') {
        # A staged stamp over nothing would let /complete-task skip a review that never saw code.
        if (-not $fp) { throw "Nothing staged in $name ($where). Stage the reviewed change before stamping Ready." }
    } else {
        if (-not $headSha) { throw "No HEAD in $name ($where). A pre-merge stamp records the reviewed commit." }
        $fp = $null
    }
    $entry = [pscustomobject]@{
        verdict     = $entryVerdict
        mode        = $Mode
        headSha     = $headSha
        fingerprint = $fp
        fpVersion   = 2
    }
    if ($null -ne $reposObj.PSObject.Properties[$name]) {
        $reposObj.$name = $entry
    } else {
        $reposObj | Add-Member -NotePropertyName $name -NotePropertyValue $entry
    }
}

$stamp = [pscustomobject]@{
    mode  = $Mode
    atUtc = [DateTime]::UtcNow.ToString('o')
    repos = $reposObj
}

Merge-TicketManifestFields -ManifestPath $manifestPath -Patch @{ reviewReady = $stamp }
Write-Host "Wrote reviewReady ($Mode) on $manifestPath" -ForegroundColor Green
