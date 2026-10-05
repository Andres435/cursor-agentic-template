#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for Get-TicketFromBranch.ps1 / Get-TicketKeyFromBranches: naming the
    ticket from each repo's current branch when the chat has no ticket folder in its path.
#>

BeforeAll {
    . (Join-Path (Join-Path $PSScriptRoot 'lib') 'ManifestFields.ps1')
    $script:Script = Join-Path $PSScriptRoot 'Get-TicketFromBranch.ps1'

    function New-BranchRepo([string]$Path, [string]$Branch) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        & git -C $Path init -q -b main
        & git -C $Path config user.email 't@example.com'
        & git -C $Path config user.name 't'
        Set-Content -LiteralPath (Join-Path $Path 'a.txt') -Value 'one'
        & git -C $Path add a.txt
        & git -C $Path commit -q -m init
        if ($Branch) { & git -C $Path switch -q -c $Branch }
    }
    function New-Workspace([string]$Name, [hashtable]$Branches, [string[]]$OpenManifests = @(), [string[]]$ClosedManifests = @()) {
        $ws = Join-Path $TestDrive $Name
        $wf = Join-Path $ws 'workflow'
        New-Item -ItemType Directory -Path (Join-Path $wf 'plans') -Force | Out-Null
        $repos = @($Branches.Keys | Sort-Object | ForEach-Object { @{ name = $_; path = "source/repos/$_" } })
        @{ ticketPrefix = 'TICKET-'; repos = $repos } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $wf 'profile.json')
        foreach ($k in $Branches.Keys) { New-BranchRepo (Join-Path $ws $k) $Branches[$k] }
        foreach ($t in $OpenManifests) { '{"mode":"branch"}' | Set-Content -LiteralPath (Join-Path $wf "plans/$t-manifest.json") }
        foreach ($t in $ClosedManifests) { '{"mode":"branch","completedAtUtc":"2026-10-01T00:00:00Z"}' | Set-Content -LiteralPath (Join-Path $wf "plans/$t-manifest.json") }
        return $wf
    }
}

AfterAll {
    Get-ChildItem -LiteralPath $TestDrive -Recurse -Force -File | ForEach-Object { $_.IsReadOnly = $false }
}

Describe 'Get-TicketFromBranch' {
    It 'names the ticket when the repos on a ticket branch agree' {
        $wf = New-Workspace 'agree' @{ Api = 'TICKET-00042'; Web = 'TICKET-00042'; Db = $null }
        & $script:Script -Root $wf | Should -Be 'TICKET-00042'
    }

    It 'prefers the ticket with an open manifest over a repo left on a closed one' {
        $wf = New-Workspace 'stale-branch' @{ Api = 'TICKET-00042'; Web = 'TICKET-00007' } -OpenManifests @('TICKET-00042') -ClosedManifests @('TICKET-00007')
        $r = & $script:Script -Root $wf -Json | ConvertFrom-Json
        $r.ticket | Should -Be 'TICKET-00042'
        $r.reason | Should -Be 'open-manifest'
        @($r.candidates).Count | Should -Be 2
    }

    It 'flags a branch whose ticket is already closed' {
        $wf = New-Workspace 'closed-only' @{ Api = 'TICKET-00007' } -ClosedManifests @('TICKET-00007')
        $r = & $script:Script -Root $wf -Json | ConvertFrom-Json
        $r.ticket | Should -Be 'TICKET-00007'
        $r.reason | Should -Be 'closed-manifest'
    }

    It 'treats a reopened ticket as open' {
        $wf = New-Workspace 'reopened' @{ Api = 'TICKET-00042'; Web = 'TICKET-00007' } -ClosedManifests @('TICKET-00007')
        '{"mode":"branch","completedAtUtc":"2026-10-01T00:00:00Z","reopenedAtUtc":"2026-10-03T00:00:00Z"}' |
            Set-Content -LiteralPath (Join-Path $wf 'plans/TICKET-00042-manifest.json')
        $r = & $script:Script -Root $wf -Json | ConvertFrom-Json
        $r.ticket | Should -Be 'TICKET-00042'
        $r.reason | Should -Be 'open-manifest'
    }

    It 'returns no ticket when two open tickets compete, so the caller asks' {
        $wf = New-Workspace 'ambiguous' @{ Api = 'TICKET-00042'; Web = 'TICKET-00043' } -OpenManifests @('TICKET-00042', 'TICKET-00043')
        $r = & $script:Script -Root $wf -Json | ConvertFrom-Json
        $r.ticket | Should -BeNullOrEmpty
        $r.reason | Should -Be 'ambiguous'
    }

    It 'reads a prefixed branch name such as feature/TICKET-00042' {
        $wf = New-Workspace 'prefixed' @{ Api = 'feature/TICKET-00042' }
        & $script:Script -Root $wf | Should -Be 'TICKET-00042'
    }

    It 'returns no ticket when every repo is on a base branch' {
        $wf = New-Workspace 'none' @{ Api = $null; Web = 'dev' }
        $r = & $script:Script -Root $wf -Json | ConvertFrom-Json
        $r.ticket | Should -BeNullOrEmpty
        $r.reason | Should -Be 'no-ticket-branch'
    }
}
