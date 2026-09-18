<#
.SYNOPSIS
    Shared helpers for reviewReady stamps, staged fingerprints, and ctxPct on
    a ticket manifest. Dot-sourced by Set-ReviewReady / Get-ReviewSkip /
    Set-TicketCtxPct. Do not run directly.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TicketKeyFromRaw {
    param([Parameter(Mandatory)][string]$Ticket)
    $digits = $Ticket -replace '[^\d]', ''
    if (-not $digits) { throw "Could not read a work item number from '$Ticket'." }
    if ($Ticket -match '^(?<pre>[A-Za-z]+-?)\d') { return $Matches['pre'] + $digits }
    return 'WI' + $digits
}

function Get-CursorRepoRoot {
    param([string]$FromScriptRoot)
    # scripts/ticket or scripts/ticket/lib → .cursor repo root
    $dir = $FromScriptRoot
    if ((Split-Path $dir -Leaf) -eq 'lib') { $dir = Split-Path $dir -Parent }
    $parent = Split-Path $dir -Parent
    if ((Split-Path $parent -Leaf) -eq 'scripts') { return (Split-Path $parent -Parent) }
    return $parent
}

function Get-TicketManifestFile {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$TicketKey
    )
    return (Join-Path (Join-Path $RepoRoot 'plans') "$TicketKey-manifest.json")
}

function Get-StagedDiffFingerprint {
    param([Parameter(Mandatory)][string]$RepoPath)
    $diff = ''
    if (Test-Path -LiteralPath $RepoPath) {
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $raw = git -C $RepoPath diff --staged 2>$null
            if ($null -ne $raw) {
                if ($raw -is [array]) { $diff = ($raw -join "`n") } else { $diff = [string]$raw }
            }
        } finally {
            $ErrorActionPreference = $prev
        }
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes($diff)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
        return (([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant())
    } finally {
        $sha.Dispose()
    }
}

function Get-ReviewSkipDecision {
    param(
        $Stamp,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$RepoPath
    )
    if (-not $Stamp) {
        return [pscustomobject]@{ repo = $Repo; skip = $false; reason = 'no-stamp'; verdict = $null }
    }
    $mode = $null
    if ($Stamp.PSObject.Properties.Name -contains 'mode') { $mode = [string]$Stamp.mode }
    if ($mode -ne 'staged') {
        return [pscustomobject]@{ repo = $Repo; skip = $false; reason = 'not-staged-mode'; verdict = $null }
    }
    $entry = $null
    if ($Stamp.PSObject.Properties.Name -contains 'repos' -and $Stamp.repos) {
        $names = @($Stamp.repos.PSObject.Properties.Name)
        if ($names -contains $Repo) { $entry = $Stamp.repos.$Repo }
    }
    if (-not $entry) {
        return [pscustomobject]@{ repo = $Repo; skip = $false; reason = 'repo-not-in-stamp'; verdict = $null }
    }
    $verdict = ''
    if ($entry.PSObject.Properties.Name -contains 'verdict') { $verdict = [string]$entry.verdict }
    if ($verdict.Trim() -ine 'Ready') {
        return [pscustomobject]@{ repo = $Repo; skip = $false; reason = 'verdict-not-ready'; verdict = $verdict }
    }
    $stored = ''
    if ($entry.PSObject.Properties.Name -contains 'fingerprint') { $stored = [string]$entry.fingerprint }
    $current = Get-StagedDiffFingerprint -RepoPath $RepoPath
    if ($current -ne $stored) {
        return [pscustomobject]@{ repo = $Repo; skip = $false; reason = 'fingerprint-mismatch'; verdict = $verdict }
    }
    return [pscustomobject]@{ repo = $Repo; skip = $true; reason = 'ready-fingerprint-match'; verdict = $verdict }
}

function Merge-TicketManifestFields {
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][hashtable]$Patch
    )
    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Manifest not found: $ManifestPath"
    }
    $obj = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($key in $Patch.Keys) {
        $val = $Patch[$key]
        if ($obj.PSObject.Properties.Name -contains $key) {
            $obj.$key = $val
        } else {
            $obj | Add-Member -NotePropertyName $key -NotePropertyValue $val
        }
    }
    $json = ConvertTo-Json -InputObject $obj -Depth 30
    [System.IO.File]::WriteAllText($ManifestPath, $json + "`n", (New-Object System.Text.UTF8Encoding $false))
}

function Get-ManifestCtxPctValue {
    param($Manifest, [string]$Phase)
    if (-not $Manifest) { return $null }
    if (-not ($Manifest.PSObject.Properties.Name -contains 'ctxPct')) { return $null }
    $ctx = $Manifest.ctxPct
    if (-not $ctx) { return $null }
    if (-not ($ctx.PSObject.Properties.Name -contains $Phase)) { return $null }
    $v = $ctx.$Phase
    if ($null -eq $v -or [string]::IsNullOrWhiteSpace([string]$v)) { return $null }
    return [int]$v
}
