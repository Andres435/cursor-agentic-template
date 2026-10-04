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
    $prefix = 'TICKET-'
    $profile = Join-Path (Get-CursorRepoRoot -FromScriptRoot $PSScriptRoot) 'profile.json'
    if (Test-Path -LiteralPath $profile) {
        try {
            $p = Get-Content -LiteralPath $profile -Raw | ConvertFrom-Json
            if ($p.ticketPrefix) { $prefix = [string]$p.ticketPrefix }
        } catch { }
    }
    return $prefix + $digits
}

function Get-CursorRepoRoot {
    param([string]$FromScriptRoot)
    # scripts/ticket or scripts/ticket/lib → tmo-agentic repo root
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

# SHA-256 of an empty string. A stamp carrying it reviewed nothing.
$script:EmptyDiffFingerprint = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'

function Get-DiffFingerprintFromText {
    param([AllowEmptyString()][string]$Diff)
    if ([string]::IsNullOrEmpty($Diff)) { return $null }
    $bytes = [Text.Encoding]::UTF8.GetBytes($Diff)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
        return (([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant())
    } finally {
        $sha.Dispose()
    }
}

# $null on a missing path or a git failure. An empty diff is '' so the caller can tell
# "nothing staged" apart from "git failed".
function Get-GitDiffText {
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string[]]$GitArgs
    )
    if (-not (Test-Path -LiteralPath $RepoPath)) { return $null }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $raw = & git -C $RepoPath @GitArgs 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        if ($null -eq $raw) { return '' }
        if ($raw -is [array]) { return ($raw -join "`n") }
        return [string]$raw
    } finally {
        $ErrorActionPreference = $prev
    }
}

# Returns $null when there is nothing to fingerprint: missing path, git failure, or an empty
# staged diff. Callers must treat $null as "no review possible", never as a match.
function Get-StagedDiffFingerprint {
    param([Parameter(Mandatory)][string]$RepoPath)
    $diff = Get-GitDiffText -RepoPath $RepoPath -GitArgs @('diff', '--staged')
    if ($null -eq $diff) { return $null }
    return (Get-DiffFingerprintFromText -Diff $diff)
}

# Staged diff when one exists; otherwise the last commit (HEAD^..HEAD).
# $null means there is nothing to compare. Callers must treat $null as "no match".
function Get-WorkDiffFingerprint {
    param([Parameter(Mandatory)][string]$RepoPath)
    $staged = Get-GitDiffText -RepoPath $RepoPath -GitArgs @('diff', '--staged')
    if ($null -ne $staged) {
        $stagedFp = Get-DiffFingerprintFromText -Diff $staged
        if ($stagedFp) { return $stagedFp }
    }
    $commit = Get-GitDiffText -RepoPath $RepoPath -GitArgs @('diff', 'HEAD^..HEAD')
    if ($null -eq $commit) { return $null }
    return (Get-DiffFingerprintFromText -Diff $commit)
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
    if (-not $stored -or $stored -eq $script:EmptyDiffFingerprint) {
        return [pscustomobject]@{ repo = $Repo; skip = $false; reason = 'empty-stamp'; verdict = $verdict }
    }
    $current = Get-StagedDiffFingerprint -RepoPath $RepoPath
    if (-not $current) {
        return [pscustomobject]@{ repo = $Repo; skip = $false; reason = 'empty-staged-diff'; verdict = $verdict }
    }
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
