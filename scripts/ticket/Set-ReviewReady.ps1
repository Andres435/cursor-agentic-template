<#
.SYNOPSIS
    Stamp reviewReady (verdict + staged fingerprint) onto a ticket manifest.

.DESCRIPTION
    Called at the end of /review-changes. Computes SHA256 of git diff --staged
    per repo and merges reviewReady so /complete-task can skip a duplicate
    review-diff when the verdict is still Ready on the same staged set.

.PARAMETER Ticket
    Work item, with or without the WI prefix.

.PARAMETER Mode
    staged (working-tree /review-changes) or pre-merge (branch token). Complete-task
    only skips on staged.

.PARAMETER Verdicts
    JSON object mapping repo name to verdict, e.g. '{"TmoPro":"Ready"}'.
    When omitted, -Verdict is applied to every resolved affected repo.

.PARAMETER Verdict
    Single verdict applied to all affected repos when -Verdicts is omitted.

.PARAMETER Root
    Override the .cursor repo root (tests).

.EXAMPLE
    .\Set-ReviewReady.ps1 -Ticket WI21961 -Mode staged -Verdicts '{"TmoPro":"Ready"}'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ticket,
    [Parameter(Mandatory)][ValidateSet('staged', 'pre-merge')][string]$Mode,
    [string]$Verdicts,
    [string]$Verdict,
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

$reposObj = New-Object PSObject
foreach ($name in ($verdictMap.Keys | Sort-Object)) {
    $path = $null
    $hit = $repoEntries | Where-Object { $_.repo -eq $name } | Select-Object -First 1
    if ($hit) { $path = [string]$hit.path }
    $fp = if ($path) { Get-StagedDiffFingerprint -RepoPath $path } else { Get-StagedDiffFingerprint -RepoPath ([IO.Path]::GetTempPath()) }
    $reposObj | Add-Member -NotePropertyName $name -NotePropertyValue ([pscustomobject]@{
        verdict     = [string]$verdictMap[$name]
        fingerprint = $fp
    })
}

$stamp = [pscustomobject]@{
    mode  = $Mode
    atUtc = [DateTime]::UtcNow.ToString('o')
    repos = $reposObj
}

Merge-TicketManifestFields -ManifestPath $manifestPath -Patch @{ reviewReady = $stamp }
Write-Host "Wrote reviewReady ($Mode) on $manifestPath" -ForegroundColor Green
