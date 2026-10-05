<#
.SYNOPSIS
    Shared helpers for reviewReady stamps, staged fingerprints, ctxPct, and
    stackSmoke on a ticket manifest. Dot-sourced by Set-ReviewReady /
    Get-ReviewSkip / Set-TicketCtxPct / Set-StackSmoke / Get-StackSmoke.
    Do not run directly.
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
    # scripts/ticket or scripts/ticket/lib → workflow repo root
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

# Pinned so a hash does not move with diff.mnemonicPrefix, core.abbrev, color, or an external
# diff driver. Stamps carry fpVersion 2 for these args. Older stamps (no fpVersion) used plain
# `git diff` and are still compared that way.
$script:CanonicalDiffArgs = @('--no-color', '--no-ext-diff', '--no-textconv', '--full-index', '--src-prefix=a/', '--dst-prefix=b/')
$script:EmptyTreeSha = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'

function Get-DiffArgsForVersion {
    param([int]$Version = 2)
    if ($Version -ge 2) { return $script:CanonicalDiffArgs }
    return @()
}

function Get-StampEntryValue {
    param($Entry, [string]$Name)
    if ($Entry -and ($Entry.PSObject.Properties.Name -contains $Name) -and $null -ne $Entry.$Name) {
        return [string]$Entry.$Name
    }
    return ''
}

function Get-EntryFingerprintVersion {
    param($Entry)
    $v = Get-StampEntryValue $Entry 'fpVersion'
    if ($v) { return [int]$v }
    return 1
}

# Returns $null when there is nothing to fingerprint: missing path, git failure, or an empty
# staged diff. Callers must treat $null as "no review possible", never as a match.
function Get-StagedDiffFingerprint {
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [int]$Version = 2
    )
    $gitArgs = @('diff') + @(Get-DiffArgsForVersion -Version $Version) + @('--staged')
    $diff = Get-GitDiffText -RepoPath $RepoPath -GitArgs $gitArgs
    if ($null -eq $diff) { return $null }
    return (Get-DiffFingerprintFromText -Diff $diff)
}

function Get-RangeDiffFingerprint {
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$From,
        [Parameter(Mandatory)][string]$To,
        [int]$Version = 2
    )
    $gitArgs = @('diff') + @(Get-DiffArgsForVersion -Version $Version) + @($From, $To)
    $diff = Get-GitDiffText -RepoPath $RepoPath -GitArgs $gitArgs
    if ($null -eq $diff) { return $null }
    return (Get-DiffFingerprintFromText -Diff $diff)
}

# Full SHA of HEAD, or $null (missing path, not a repo, unborn branch).
function Get-GitHeadSha {
    param([Parameter(Mandatory)][string]$RepoPath)
    $sha = Get-GitDiffText -RepoPath $RepoPath -GitArgs @('rev-parse', '--verify', '--quiet', 'HEAD')
    if (-not $sha) { return $null }
    return $sha.Trim().ToLowerInvariant()
}

# First-parent commits newest first, as { sha; parent; isMerge }. With -Since, only the commits
# after it. First-parent keeps a merged-in base branch (prep-pr merges origin/dev) out of the walk.
function Get-FirstParentCommits {
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [string]$Since,
        [int]$Limit = 50
    )
    $range = if ($Since) { "$Since..HEAD" } else { 'HEAD' }
    $raw = Get-GitDiffText -RepoPath $RepoPath -GitArgs @('rev-list', '--first-parent', '--parents', "--max-count=$Limit", $range)
    if ($null -eq $raw) { return @() }
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($line in ($raw -split "`n")) {
        $parts = @($line.Trim() -split '\s+' | Where-Object { $_ })
        if ($parts.Count -eq 0) { continue }
        $parent = if ($parts.Count -gt 1) { $parts[1] } else { $null }
        [void]$list.Add([pscustomobject]@{ sha = $parts[0]; parent = $parent; isMerge = ($parts.Count -gt 2) })
    }
    return $list.ToArray()
}

function Test-GitIsAncestor {
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$Ancestor
    )
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & git -C $RepoPath merge-base --is-ancestor $Ancestor HEAD 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } finally {
        $ErrorActionPreference = $prev
    }
}

# Staged diff when one exists; otherwise the newest first-parent non-merge commit, so a merge of
# the base branch does not count as the work. $null means there is nothing to compare.
function Get-WorkDiffFingerprint {
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [int]$Version = 2
    )
    $staged = Get-StagedDiffFingerprint -RepoPath $RepoPath -Version $Version
    if ($staged) { return $staged }
    $work = @(Get-FirstParentCommits -RepoPath $RepoPath | Where-Object { -not $_.isMerge }) | Select-Object -First 1
    if (-not $work) { return $null }
    $from = if ($work.parent) { $work.parent } else { $script:EmptyTreeSha }
    return (Get-RangeDiffFingerprint -RepoPath $RepoPath -From $from -To $work.sha -Version $Version)
}

function Test-ReviewVerdict {
    param([AllowNull()][AllowEmptyString()][string]$Verdict)
    $v = ([string]$Verdict).Replace('*', '').Trim()
    return ($v -in @('Ready', 'Ready with fixes', 'No change'))
}

# Does the repo still hold exactly the work this review stamp saw? Returns { ok; reason }.
# Staged stamp: the staged diff matches, or, once committed, headSha..newest first-parent
#   non-merge commit matches. Splitting the reviewed set across commits is fine, and a merge of
#   the base branch afterwards is ignored. Any edit after the review changes the hash.
# No change / pre-merge: nothing staged, headSha still on the branch, and only merges after it.
# Legacy stamp (no headSha): version-1 hash of the staged diff or of the newest non-merge commit.
function Test-ReviewedWorkPresent {
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)]$Entry,
        [string]$StampMode = 'staged'
    )
    $verdict = (Get-StampEntryValue $Entry 'verdict').Replace('*', '').Trim()
    $mode = Get-StampEntryValue $Entry 'mode'
    if (-not $mode) { $mode = $StampMode }
    $headSha = (Get-StampEntryValue $Entry 'headSha').ToLowerInvariant()
    $fp = (Get-StampEntryValue $Entry 'fingerprint').ToLowerInvariant()
    $version = Get-EntryFingerprintVersion $Entry
    $staged = Get-StagedDiffFingerprint -RepoPath $RepoPath -Version $version

    if ($verdict -eq 'No change' -or $mode -eq 'pre-merge') {
        if ($staged) { return [pscustomobject]@{ ok = $false; reason = 'staged change after the review' } }
        if (-not $headSha) { return [pscustomobject]@{ ok = $false; reason = 'stamp has no headSha' } }
        if (-not (Test-GitIsAncestor -RepoPath $RepoPath -Ancestor $headSha)) {
            return [pscustomobject]@{ ok = $false; reason = 'reviewed commit is not on this branch (rebased, or another branch is checked out)' }
        }
        $after = @(Get-FirstParentCommits -RepoPath $RepoPath -Since $headSha | Where-Object { -not $_.isMerge })
        if ($after.Count -gt 0) { return [pscustomobject]@{ ok = $false; reason = "$($after.Count) commit(s) after the review" } }
        $why = if ($verdict -eq 'No change') { 'no-change' } else { 'pre-merge-head' }
        return [pscustomobject]@{ ok = $true; reason = $why }
    }

    if ($staged) {
        if ($staged -eq $fp) { return [pscustomobject]@{ ok = $true; reason = 'staged-match' } }
        return [pscustomobject]@{ ok = $false; reason = 'staged diff differs from the reviewed diff' }
    }

    if ($headSha) {
        if (-not (Test-GitIsAncestor -RepoPath $RepoPath -Ancestor $headSha)) {
            return [pscustomobject]@{ ok = $false; reason = 'review base is not on this branch (rebased, or another branch is checked out)' }
        }
        $work = @(Get-FirstParentCommits -RepoPath $RepoPath -Since $headSha | Where-Object { -not $_.isMerge }) | Select-Object -First 1
        if (-not $work) { return [pscustomobject]@{ ok = $false; reason = 'reviewed change is neither staged nor committed' } }
        $current = Get-RangeDiffFingerprint -RepoPath $RepoPath -From $headSha -To $work.sha -Version $version
        if ($current -and $current -eq $fp) { return [pscustomobject]@{ ok = $true; reason = 'commit-match' } }
        return [pscustomobject]@{ ok = $false; reason = 'committed work differs from the reviewed diff' }
    }

    $legacy = Get-WorkDiffFingerprint -RepoPath $RepoPath -Version 1
    if ($legacy -and $legacy -eq $fp) { return [pscustomobject]@{ ok = $true; reason = 'legacy-commit-match' } }
    return [pscustomobject]@{ ok = $false; reason = 'does not match the staged diff or last commit' }
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
    $entry = $null
    if ($Stamp.PSObject.Properties.Name -contains 'repos' -and $Stamp.repos) {
        $names = @($Stamp.repos.PSObject.Properties.Name)
        if ($names -contains $Repo) { $entry = $Stamp.repos.$Repo }
    }
    $mode = Get-StampEntryValue $entry 'mode'
    if (-not $mode) { $mode = Get-StampEntryValue $Stamp 'mode' }
    if ($mode -ne 'staged') {
        return [pscustomobject]@{ repo = $Repo; skip = $false; reason = 'not-staged-mode'; verdict = $null }
    }
    if (-not $entry) {
        return [pscustomobject]@{ repo = $Repo; skip = $false; reason = 'repo-not-in-stamp'; verdict = $null }
    }
    $verdict = Get-StampEntryValue $entry 'verdict'
    $current = Get-StagedDiffFingerprint -RepoPath $RepoPath -Version (Get-EntryFingerprintVersion $entry)
    if ($verdict.Trim() -ieq 'No change') {
        if ($current) {
            return [pscustomobject]@{ repo = $Repo; skip = $false; reason = 'staged-after-no-change'; verdict = $verdict }
        }
        return [pscustomobject]@{ repo = $Repo; skip = $true; reason = 'no-change'; verdict = $verdict }
    }
    if ($verdict.Trim() -ine 'Ready') {
        return [pscustomobject]@{ repo = $Repo; skip = $false; reason = 'verdict-not-ready'; verdict = $verdict }
    }
    $stored = Get-StampEntryValue $entry 'fingerprint'
    if (-not $stored -or $stored -eq $script:EmptyDiffFingerprint) {
        return [pscustomobject]@{ repo = $Repo; skip = $false; reason = 'empty-stamp'; verdict = $verdict }
    }
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

function Get-StackSmokeWorkFingerprint {
    param([hashtable]$RepoPaths)
    if (-not $RepoPaths -or $RepoPaths.Count -eq 0) { return $null }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($name in ($RepoPaths.Keys | Sort-Object)) {
        $path = [string]$RepoPaths[$name]
        $fp = if ($path) { Get-WorkDiffFingerprint -RepoPath $path } else { $null }
        if ($fp) { [void]$parts.Add("$name=$fp") }
    }
    if ($parts.Count -eq 0) { return $null }
    return (Get-DiffFingerprintFromText -Diff ($parts -join "`n"))
}

function Get-StackSmokeDecision {
    param(
        $Stamp,
        [hashtable]$RepoPaths
    )
    $labels = @{
        never   = 'Never tested'
        passed  = 'Tested'
        failed  = 'Failed'
        skipped = 'Skipped'
        stale   = 'Untested latest changes'
    }
    $recorded = 'never'
    $storedFp = ''
    $lastStatus = $null
    if ($Stamp) {
        if ($Stamp.PSObject.Properties.Name -contains 'status' -and $Stamp.status) {
            $recorded = [string]$Stamp.status
        }
        if ($Stamp.PSObject.Properties.Name -contains 'fingerprint') {
            $storedFp = [string]$Stamp.fingerprint
        }
        if ($Stamp.PSObject.Properties.Name -contains 'lastStatus' -and $Stamp.lastStatus) {
            $lastStatus = [string]$Stamp.lastStatus
        }
    }
    if ($recorded -eq 'never') {
        return [pscustomobject]@{ recorded = 'never'; effective = 'never'; reason = 'no-stamp'; label = $labels.never }
    }
    if ($recorded -eq 'skipped') {
        return [pscustomobject]@{ recorded = 'skipped'; effective = 'skipped'; reason = 'skipped'; label = $labels.skipped }
    }
    if ($recorded -eq 'stale') {
        return [pscustomobject]@{ recorded = 'stale'; effective = 'stale'; reason = 'marked-stale'; label = $labels.stale; lastStatus = $lastStatus }
    }
    $current = Get-StackSmokeWorkFingerprint -RepoPaths $RepoPaths
    if ($recorded -in @('passed', 'failed')) {
        if ($storedFp -and $current -and ($storedFp -eq $current)) {
            return [pscustomobject]@{ recorded = $recorded; effective = $recorded; reason = 'fingerprint-match'; label = $labels[$recorded] }
        }
        if ($storedFp -and $current -and ($storedFp -ne $current)) {
            return [pscustomobject]@{ recorded = $recorded; effective = 'stale'; reason = 'fingerprint-mismatch'; label = $labels.stale; lastStatus = $recorded }
        }
        if (-not $storedFp -and $current) {
            return [pscustomobject]@{ recorded = $recorded; effective = 'stale'; reason = 'no-stored-fingerprint'; label = $labels.stale; lastStatus = $recorded }
        }
        return [pscustomobject]@{ recorded = $recorded; effective = $recorded; reason = 'no-current-fingerprint'; label = $labels[$recorded] }
    }
    return [pscustomobject]@{ recorded = $recorded; effective = $recorded; reason = 'unknown-status'; label = $recorded }
}
