# Invoke-Pester ./scripts/worktree/Remove-MergedTicketBranches.Tests.ps1 -Output Detailed
#Requires -Modules Pester

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:RemoveScript = Join-Path $PSScriptRoot 'Remove-MergedTicketBranches.ps1'
    $profilePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'profile.json'
    $profileJson = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
    $script:Prefix = [string]$profileJson.ticketPrefix
    $script:Base = [string]$profileJson.baseBranchDefault
    if (-not $script:Prefix) { $script:Prefix = 'WI' }
    if (-not $script:Base) { $script:Base = 'main' }
    $script:Squashed = $script:Prefix + '21903'
    $script:Merged = $script:Prefix + '21904'
    $script:Unmerged = $script:Prefix + '21905'

    function Invoke-GitQ {
        param([string]$Repo, [string[]]$Arguments)
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { return @(git -C $Repo @Arguments 2>$null) }
        finally { $ErrorActionPreference = $prev }
    }

    function Get-TicketHeads([string]$Repo) {
        @(Invoke-GitQ $Repo @('for-each-ref', '--format=%(refname:short)', "refs/heads/$($script:Prefix)*"))
    }

    function Initialize-GitRepo([string]$Path) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        & git -C $Path init -q
        & git -C $Path config user.email 't@example.com'
        & git -C $Path config user.name 't'
        & git -C $Path config commit.gpgsign false
        & git -C $Path symbolic-ref HEAD "refs/heads/$($script:Base)"
        Set-Content -LiteralPath (Join-Path $Path 'README.md') -Value 'init'
        & git -C $Path add README.md
        & git -C $Path commit -q -m init
    }

    function Connect-Origin([string]$Repo, [string]$Bare) {
        New-Item -ItemType Directory -Path $Bare -Force | Out-Null
        & git -C $Bare init -q --bare
        & git -C $Repo remote add origin $Bare
        & git -C $Repo push -q origin $script:Base
    }

    function Add-SquashedBranch([string]$Repo, [string]$Branch) {
        & git -C $Repo checkout -q -b $Branch
        Set-Content -LiteralPath (Join-Path $Repo 'squash.txt') -Value 'shipped'
        & git -C $Repo add squash.txt
        & git -C $Repo commit -q -m "ticket $Branch"
        & git -C $Repo checkout -q $script:Base
        Set-Content -LiteralPath (Join-Path $Repo 'squash.txt') -Value 'shipped'
        & git -C $Repo add squash.txt
        & git -C $Repo commit -q -m "squash of $Branch"
        & git -C $Repo push -q origin $script:Base
    }

    function Add-MergedBranch([string]$Repo, [string]$Branch) {
        & git -C $Repo checkout -q -b $Branch
        Set-Content -LiteralPath (Join-Path $Repo 'merged.txt') -Value 'merged'
        & git -C $Repo add merged.txt
        & git -C $Repo commit -q -m "ticket $Branch"
        & git -C $Repo checkout -q $script:Base
        & git -C $Repo merge --no-ff -m "merge $Branch" $Branch
        & git -C $Repo push -q origin $script:Base
    }

    function Add-UnmergedBranch([string]$Repo, [string]$Branch) {
        & git -C $Repo checkout -q -b $Branch
        Set-Content -LiteralPath (Join-Path $Repo 'unique.txt') -Value 'unique'
        & git -C $Repo add unique.txt
        & git -C $Repo commit -q -m "ticket $Branch"
        & git -C $Repo checkout -q $script:Base
    }

    function New-CleanupFixture([string]$Name) {
        $reposRoot = Join-Path $TestDrive $Name
        $repo = Join-Path $reposRoot 'app'
        $bare = Join-Path $TestDrive "$Name-origin.git"
        Initialize-GitRepo $repo
        Connect-Origin $repo $bare
        Add-SquashedBranch $repo $script:Squashed
        Add-MergedBranch $repo $script:Merged
        Add-UnmergedBranch $repo $script:Unmerged
        return [pscustomobject]@{ ReposRoot = $reposRoot; Repo = $repo }
    }

    function Invoke-Cleanup {
        param(
            [string]$ReposRoot,
            [switch]$Force,
            [switch]$WhatIf,
            [switch]$IncludeUnmerged
        )
        $splat = @{ ReposRoot = $ReposRoot }
        if ($Force) { $splat['Force'] = $true }
        if ($WhatIf) { $splat['WhatIf'] = $true }
        if ($IncludeUnmerged) { $splat['IncludeUnmerged'] = $true }
        $script:lastOutput = & $script:RemoveScript @splat *>&1 | ForEach-Object { "$_" }
        return ($script:lastOutput -join "`n")
    }
}

AfterAll {
    Get-ChildItem -LiteralPath $TestDrive -Recurse -Force -File -ErrorAction SilentlyContinue |
        ForEach-Object { $_.IsReadOnly = $false }
}

Describe 'Remove-MergedTicketBranches' {
    It 'WhatIf leaves every ticket branch and prints branch -D previews' {
        $fx = New-CleanupFixture 'whatif'
        $text = Invoke-Cleanup -ReposRoot $fx.ReposRoot -WhatIf
        Get-TicketHeads $fx.Repo | Should -Contain $script:Squashed
        Get-TicketHeads $fx.Repo | Should -Contain $script:Merged
        Get-TicketHeads $fx.Repo | Should -Contain $script:Unmerged
        $text | Should -Match ('\[WhatIf\].*branch -D ' + [regex]::Escape($script:Squashed))
        $text | Should -Match ('\[WhatIf\].*branch -D ' + [regex]::Escape($script:Merged))
        $text | Should -Not -Match ('\[WhatIf\].*branch -D ' + [regex]::Escape($script:Unmerged))
    }

    It 'Force -WhatIf is a preview, not a delete' {
        $fx = New-CleanupFixture 'force-whatif'
        $text = Invoke-Cleanup -ReposRoot $fx.ReposRoot -Force -WhatIf
        Get-TicketHeads $fx.Repo | Should -Contain $script:Squashed
        Get-TicketHeads $fx.Repo | Should -Contain $script:Merged
        Get-TicketHeads $fx.Repo | Should -Contain $script:Unmerged
        $text | Should -Match ('\[WhatIf\].*branch -D ' + [regex]::Escape($script:Squashed))
        $text | Should -Match ('\[WhatIf\].*branch -D ' + [regex]::Escape($script:Merged))
    }

    It 'Force deletes merged and squashed only' {
        $fx = New-CleanupFixture 'force'
        Invoke-Cleanup -ReposRoot $fx.ReposRoot -Force | Out-Null
        Get-TicketHeads $fx.Repo | Should -Not -Contain $script:Squashed
        Get-TicketHeads $fx.Repo | Should -Not -Contain $script:Merged
        Get-TicketHeads $fx.Repo | Should -Contain $script:Unmerged
    }

    It 'Force -IncludeUnmerged also deletes the unique unmerged branch' {
        $fx = New-CleanupFixture 'include-unmerged'
        Invoke-Cleanup -ReposRoot $fx.ReposRoot -Force -IncludeUnmerged | Out-Null
        Get-TicketHeads $fx.Repo | Should -Not -Contain $script:Squashed
        Get-TicketHeads $fx.Repo | Should -Not -Contain $script:Merged
        Get-TicketHeads $fx.Repo | Should -Not -Contain $script:Unmerged
    }

    It 'does not delete a merged branch that is checked out' {
        $fx = New-CleanupFixture 'checked-out'
        & git -C $fx.Repo checkout -q $script:Merged
        Invoke-Cleanup -ReposRoot $fx.ReposRoot -Force | Out-Null
        Get-TicketHeads $fx.Repo | Should -Contain $script:Merged
        Get-TicketHeads $fx.Repo | Should -Not -Contain $script:Squashed
        Get-TicketHeads $fx.Repo | Should -Contain $script:Unmerged
    }

    It 'without Force reports and does not delete' {
        $fx = New-CleanupFixture 'report'
        $text = Invoke-Cleanup -ReposRoot $fx.ReposRoot
        Get-TicketHeads $fx.Repo | Should -Contain $script:Squashed
        Get-TicketHeads $fx.Repo | Should -Contain $script:Merged
        Get-TicketHeads $fx.Repo | Should -Contain $script:Unmerged
        $text | Should -Match 'would be deleted'
        $text | Should -Not -Match '\[WhatIf\]'
    }
}
