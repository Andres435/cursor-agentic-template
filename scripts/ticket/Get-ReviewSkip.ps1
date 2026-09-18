<#
.SYNOPSIS
    Decide whether /complete-task should skip review-diff per repo.

.DESCRIPTION
    Skip only when reviewReady.mode is staged, the repo verdict is exactly Ready,
    and git diff --staged still matches the stored fingerprint.

.PARAMETER Ticket
    Work item, with or without the WI prefix.

.PARAMETER Json
    Emit { ticket, mode, repos: [{ repo, skip, reason, verdict }] }.

.PARAMETER Root
    Override the .cursor repo root (tests).

.EXAMPLE
    .\Get-ReviewSkip.ps1 -Ticket WI21961 -Json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ticket,
    [switch]$Json,
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path (Join-Path $PSScriptRoot 'lib') 'ManifestFields.ps1')

$Key = Get-TicketKeyFromRaw -Ticket $Ticket
$RepoRoot = if ($Root) { $Root } else { Get-CursorRepoRoot -FromScriptRoot $PSScriptRoot }
$manifestPath = Get-TicketManifestFile -RepoRoot $RepoRoot -TicketKey $Key

$stamp = $null
if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.PSObject.Properties.Name -contains 'reviewReady') {
        $stamp = $manifest.reviewReady
    }
}

$resolveScript = Join-Path $PSScriptRoot 'Resolve-TicketRoot.ps1'
$repoEntries = @()
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $resolvedJson = & $resolveScript -Ticket $Key -Json 2>$null
    if ($LASTEXITCODE -eq 0 -and $resolvedJson) {
        $resolved = $resolvedJson | ConvertFrom-Json
        if ($resolved.repos) { $repoEntries = @($resolved.repos) }
    }
} finally {
    $ErrorActionPreference = $prevEap
}

if (-not $repoEntries.Count -and $stamp -and $stamp.repos) {
    foreach ($p in $stamp.repos.PSObject.Properties) {
        $repoEntries += [pscustomobject]@{ repo = $p.Name; path = $RepoRoot; exists = $false }
    }
}

$decisions = @()
foreach ($r in $repoEntries) {
    $path = if ($r.PSObject.Properties.Name -contains 'path') { [string]$r.path } else { $RepoRoot }
    $decisions += Get-ReviewSkipDecision -Stamp $stamp -Repo $r.repo -RepoPath $path
}

$stampMode = $null
if ($stamp -and ($stamp.PSObject.Properties.Name -contains 'mode')) { $stampMode = [string]$stamp.mode }

$result = [pscustomobject]@{
    ticket = $Key
    mode   = $stampMode
    repos  = @($decisions)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
    exit 0
}

Write-Host ("{0}: review skip ({1})" -f $Key, $(if ($stampMode) { $stampMode } else { 'no-stamp' }))
foreach ($d in $decisions) {
    $flag = if ($d.skip) { 'SKIP' } else { 'REVIEW' }
    Write-Host ("    {0,-8} {1,-26} {2}" -f $flag, $d.repo, $d.reason)
}
exit 0
