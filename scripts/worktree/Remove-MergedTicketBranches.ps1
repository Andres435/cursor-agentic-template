<#
.SYNOPSIS
    Deletes local ticket branches whose work has already landed on their base branch.

.DESCRIPTION
    Ancestry alone cannot decide this. Squash-merged work is not an ancestor of the
    base, so `git branch --merged` calls it unmerged. This script classifies each
    branch two ways:

      merged    - branch is an ancestor of its base
      squashed  - every commit has a patch-equivalent already on base (`git cherry`)
      unmerged  - has at least one patch not present on base
      worktree  - still checked out in a live worktree; never touched

    Only `merged` and `squashed` are deleted by default. The ticket prefix and the
    base branch come from profile.json (`ticketPrefix`, `baseBranchDefault`).

.PARAMETER Ticket
    Optional. Limit to one ticket (prefix plus digits, or digits only).

.PARAMETER Repos
    Optional. Limit to these clone folder names. Omit for every git repo under -ReposRoot.

.PARAMETER IncludeUnmerged
    Also delete branches with commits that are not on the base branch.
    Destructive. Requires -Force too.

.PARAMETER Force
    Actually delete. Without it this is a report only.

.PARAMETER WhatIf
    Preview the git branch -D commands without deleting. Classification
    (including fetch) still runs. -Force -WhatIf is a preview, not a delete.

.PARAMETER KeepRemote
    Do not report branches that still have an origin counterpart as deletable.

.PARAMETER ReposRoot
    Canonical clones folder. Tests pass a temp tree. Default is the parent of
    this repo (the layout `source/repos` uses).

.EXAMPLE
    .\Remove-MergedTicketBranches.ps1 -Force -WhatIf
#>

[CmdletBinding()]
param(
    [string]$Ticket,
    [string[]]$Repos,
    [switch]$IncludeUnmerged,
    [switch]$Force,
    [switch]$WhatIf,
    [switch]$KeepRemote,
    [string]$ReposRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot ".." "_ServiceLauncherLib.ps1")

if (-not $ReposRoot) {
    $ReposRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
}
$ReposRoot = Get-CanonicalReposRoot -ReposRoot $ReposRoot

$ticketFilter = $null
if ($Ticket) {
    $ticketFilter = ConvertTo-LauncherTicketId -Raw $Ticket
    if (-not $ticketFilter) { throw "Could not read a ticket number from '$Ticket'." }
}

function Get-CleanupBaseBranch {
    $profilePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'profile.json'
    if (Test-Path -LiteralPath $profilePath) {
        try {
            $p = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
            if ($p.baseBranchDefault) { return [string]$p.baseBranchDefault }
        } catch { }
    }
    return 'main'
}

function Invoke-Git {
    param([string]$Repo, [string[]]$Arguments)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { return @(git -C $Repo @Arguments 2>$null) }
    finally { $ErrorActionPreference = $prev }
}

$prefix = Get-WorkflowTicketPrefix
$base = Get-CleanupBaseBranch
$repoDirs = Get-ChildItem -Path $ReposRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { -not $_.Name.StartsWith('.') } |
    Where-Object { Test-Path (Join-Path $_.FullName '.git') } |
    Where-Object { -not $Repos -or $Repos -contains $_.Name }

$rows = [System.Collections.Generic.List[object]]::new()

foreach ($dir in $repoDirs) {
    $repo = $dir.Name
    $path = $dir.FullName

    $branches = @(Invoke-Git $path @('for-each-ref', '--format=%(refname:short)', "refs/heads/$prefix*"))
    if (-not $branches.Count) { continue }

    Invoke-Git $path @('fetch', 'origin', '--prune', '--quiet') | Out-Null

    $checkedOut = @(Invoke-Git $path @('worktree', 'list', '--porcelain') |
        Select-String '^branch refs/heads/' | ForEach-Object { $_.Line -replace '^branch refs/heads/', '' })

    foreach ($branch in $branches) {
        if ($ticketFilter -and ($branch -split '-on-')[0] -ne $ticketFilter) { continue }

        if ($branch -eq $base) {
            $rows.Add([pscustomobject]@{ Repo = $repo; Branch = $branch; Base = $base; State = 'base-branch'; Unique = 0; HasRemote = $true })
            continue
        }

        $baseRef = "origin/$base"
        Invoke-Git $path @('rev-parse', '--verify', '--quiet', $baseRef) | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $rows.Add([pscustomobject]@{ Repo = $repo; Branch = $branch; Base = $base; State = 'no-base'; Unique = 0; HasRemote = $false })
            continue
        }

        if ($checkedOut -contains $branch) {
            $rows.Add([pscustomobject]@{ Repo = $repo; Branch = $branch; Base = $base; State = 'worktree'; Unique = 0; HasRemote = $false })
            continue
        }

        Invoke-Git $path @('rev-parse', '--verify', '--quiet', "refs/remotes/origin/$branch") | Out-Null
        $hasRemote = ($LASTEXITCODE -eq 0)

        Invoke-Git $path @('merge-base', '--is-ancestor', $branch, $baseRef) | Out-Null
        $isAncestor = ($LASTEXITCODE -eq 0)

        if ($isAncestor) {
            $state = 'merged'; $unique = 0
        }
        else {
            $cherry = @(Invoke-Git $path @('cherry', $baseRef, $branch))
            $unique = @($cherry | Where-Object { $_ -match '^\+' }).Count
            if ($unique -eq 0) {
                $state = 'squashed'
            }
            else {
                $state = if ($hasRemote) { 'unmerged-pushed' } else { 'unmerged-local' }
            }
        }

        $rows.Add([pscustomobject]@{
            Repo = $repo; Branch = $branch; Base = $base
            State = $state; Unique = $unique; HasRemote = $hasRemote
        })
    }
}

if (-not $rows.Count) {
    Write-LauncherSkip "No $prefix* branches found$(if($ticketFilter){" for $ticketFilter"})."
    return
}

Write-Host ""
foreach ($g in ($rows | Group-Object State | Sort-Object Name)) {
    $color = switch ($g.Name) {
        'merged'          { 'Green' }
        'squashed'        { 'Green' }
        'unmerged-pushed' { 'Yellow' }
        'unmerged-local'  { 'Red' }
        default           { 'DarkGray' }
    }
    Write-Host ("{0} ({1})" -f $g.Name, $g.Count) -ForegroundColor $color
    foreach ($r in ($g.Group | Sort-Object Repo, Branch)) {
        $note = @()
        if ($r.Unique -gt 0) { $note += "$($r.Unique) unique commit(s)" }
        if ($r.HasRemote) { $note += 'origin branch still exists' }
        Write-Host ("   {0,-22} {1,-18} base {2,-8} {3}" -f $r.Repo, $r.Branch, $r.Base, ($note -join '; '))
    }
}

$deletable = @($rows | Where-Object {
    ($_.State -eq 'merged' -or $_.State -eq 'squashed' -or
     ($IncludeUnmerged -and $_.State -like 'unmerged-*')) -and
    -not ($KeepRemote -and $_.HasRemote)
})

Write-Host ""
if (-not $deletable.Count) {
    Write-LauncherSkip "Nothing deletable under the current switches."
    return
}

if ($WhatIf) {
    foreach ($r in $deletable) {
        $path = Join-Path $ReposRoot $r.Repo
        Write-LauncherDoing ("[WhatIf] git -C {0} branch -D {1}" -f $path, $r.Branch)
    }
    return
}

if (-not $Force) {
    Write-LauncherDoing "$($deletable.Count) branch(es) would be deleted. Re-run with -Force to apply."
    return
}

$done = 0; $failed = 0
foreach ($r in $deletable) {
    $path = Join-Path $ReposRoot $r.Repo
    $out = Invoke-Git $path @('branch', '-D', $r.Branch)
    if ($LASTEXITCODE -eq 0) {
        Write-LauncherOk ("{0} / {1} ({2})" -f $r.Repo, $r.Branch, $r.State)
        $done++
    }
    else {
        Write-LauncherFail ("{0} / {1} - {2}" -f $r.Repo, $r.Branch, ($out -join ' '))
        $failed++
    }
}

Write-Host ""
Write-Host "Deleted $done branch(es); $failed failed." -ForegroundColor $(if ($failed) { 'Yellow' } else { 'Green' })
if (-not $IncludeUnmerged) {
    $pushed = @($rows | Where-Object { $_.State -eq 'unmerged-pushed' }).Count
    $local = @($rows | Where-Object { $_.State -eq 'unmerged-local' }).Count
    if ($pushed) { Write-LauncherSkip "$pushed unmerged branch(es) kept, still on origin - deleting them locally is recoverable by re-fetching." }
    if ($local) { Write-LauncherFail "$local unmerged branch(es) kept and NOT on origin - deleting them loses those commits for good." }
}
