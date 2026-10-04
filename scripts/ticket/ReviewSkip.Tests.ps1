#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for review skip decisions and ctxPct / reviewReady stamps.
#>

BeforeAll {
    $lib = Join-Path (Join-Path $PSScriptRoot 'lib') 'ManifestFields.ps1'
    . $lib

    # A git repo with one staged change, and one with nothing staged.
    function New-TestRepo([string]$Path, [switch]$Staged) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        & git -C $Path init -q
        & git -C $Path config user.email 't@example.com'
        & git -C $Path config user.name 't'
        Set-Content -LiteralPath (Join-Path $Path 'a.txt') -Value 'one'
        & git -C $Path add a.txt
        & git -C $Path commit -q -m init
        if ($Staged) {
            Set-Content -LiteralPath (Join-Path $Path 'a.txt') -Value 'two'
            & git -C $Path add a.txt
        }
    }
    $script:StagedRepo = Join-Path $TestDrive 'staged'
    $script:CleanRepo  = Join-Path $TestDrive 'clean'
    New-TestRepo $script:StagedRepo -Staged
    New-TestRepo $script:CleanRepo
    $script:StagedHash = Get-StagedDiffFingerprint -RepoPath $script:StagedRepo
}

AfterAll {
    # git writes object files read-only on Windows, which breaks Pester's TestDrive cleanup.
    Get-ChildItem -LiteralPath $TestDrive -Recurse -Force -File | ForEach-Object { $_.IsReadOnly = $false }
}

Describe 'Get-StagedDiffFingerprint' {
    It 'hashes a staged change' {
        $script:StagedHash | Should -Match '^[0-9a-f]{64}$'
    }

    It 'returns null when nothing is staged' {
        Get-StagedDiffFingerprint -RepoPath $script:CleanRepo | Should -BeNullOrEmpty
    }

    It 'returns null for a folder that is not a git repo' {
        Get-StagedDiffFingerprint -RepoPath $TestDrive | Should -BeNullOrEmpty
    }
}

Describe 'Get-ReviewSkipDecision' {
    It 'skips when Ready and fingerprint matches' {
        $stamp = [pscustomobject]@{
            mode  = 'staged'
            repos = [pscustomobject]@{ TmoPro = [pscustomobject]@{ verdict = 'Ready'; fingerprint = $script:StagedHash } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'TmoPro' -RepoPath $script:StagedRepo
        $d.skip | Should -Be $true
        $d.reason | Should -Be 'ready-fingerprint-match'
    }

    It 'does not skip Ready with fixes' {
        $stamp = [pscustomobject]@{
            mode  = 'staged'
            repos = [pscustomobject]@{ TmoPro = [pscustomobject]@{ verdict = 'Ready with fixes'; fingerprint = $script:StagedHash } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'TmoPro' -RepoPath $script:StagedRepo
        $d.skip | Should -Be $false
        $d.reason | Should -Be 'verdict-not-ready'
    }

    It 'does not skip when fingerprint mismatches' {
        $stamp = [pscustomobject]@{
            mode  = 'staged'
            repos = [pscustomobject]@{ TmoPro = [pscustomobject]@{ verdict = 'Ready'; fingerprint = 'deadbeef' } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'TmoPro' -RepoPath $script:StagedRepo
        $d.skip | Should -Be $false
        $d.reason | Should -Be 'fingerprint-mismatch'
    }

    It 'does not skip a stamp of the empty diff, even when nothing is staged now' {
        $stamp = [pscustomobject]@{
            mode  = 'staged'
            repos = [pscustomobject]@{ TmoPro = [pscustomobject]@{ verdict = 'Ready'; fingerprint = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'TmoPro' -RepoPath $script:CleanRepo
        $d.skip | Should -Be $false
        $d.reason | Should -Be 'empty-stamp'
    }

    It 'does not skip when the staged set is now empty' {
        $stamp = [pscustomobject]@{
            mode  = 'staged'
            repos = [pscustomobject]@{ TmoPro = [pscustomobject]@{ verdict = 'Ready'; fingerprint = $script:StagedHash } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'TmoPro' -RepoPath $script:CleanRepo
        $d.skip | Should -Be $false
        $d.reason | Should -Be 'empty-staged-diff'
    }

    It 'does not skip a missing stamp' {
        $d = Get-ReviewSkipDecision -Stamp $null -Repo 'TmoPro' -RepoPath ([IO.Path]::GetTempPath())
        $d.skip | Should -Be $false
        $d.reason | Should -Be 'no-stamp'
    }

    It 'does not skip pre-merge mode' {
        $stamp = [pscustomobject]@{
            mode  = 'pre-merge'
            repos = [pscustomobject]@{ TmoPro = [pscustomobject]@{ verdict = 'Ready'; fingerprint = $script:StagedHash } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'TmoPro' -RepoPath $script:StagedRepo
        $d.skip | Should -Be $false
        $d.reason | Should -Be 'not-staged-mode'
    }
}

Describe 'Set-TicketCtxPct and Set-ReviewReady against a temp manifest' {
    It 'writes ctxPct.start without dropping other fields' {
        $root = Join-Path $TestDrive 'ctx-root'
        $tmp = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $mf = Join-Path $tmp 'WI00002-manifest.json'
        '{"mode":"branch","workType":"bug"}' | Set-Content -LiteralPath $mf -Encoding UTF8
        $script = Join-Path $PSScriptRoot 'Set-TicketCtxPct.ps1'
        & $script -Ticket WI00002 -Phase start -Percent 81 -Root $root
        $got = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
        $got.mode | Should -Be 'branch'
        [int]$got.ctxPct.start | Should -Be 81
        $got.ctxPctSource.start | Should -Be 'reported'
    }

    It 'uses the measured value for this session when -Percent is omitted' {
        $root = Join-Path $TestDrive 'ctx-measured'
        $tmp = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $mf = Join-Path $tmp 'WI00006-manifest.json'
        '{"mode":"branch"}' | Set-Content -LiteralPath $mf -Encoding UTF8
        $usage = Join-Path $TestDrive 'ctx-usage.json'
        $now = [DateTime]::UtcNow.ToString('o')
        @{ latest = @{ session = 'other'; pct = 12; at = $now }
           sessions = @{ mine = @{ session = 'mine'; pct = 47; at = $now }; other = @{ session = 'other'; pct = 12; at = $now } } } |
            ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $usage
        $env:TMO_CTX_USAGE_FILE = $usage
        $env:TMO_SESSION_ID = 'mine'
        try {
            & (Join-Path $PSScriptRoot 'Set-TicketCtxPct.ps1') -Ticket WI00006 -Phase review -Root $root
        } finally {
            Remove-Item Env:TMO_CTX_USAGE_FILE, Env:TMO_SESSION_ID -ErrorAction SilentlyContinue
        }
        $got = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
        [int]$got.ctxPct.review | Should -Be 47
        $got.ctxPctSource.review | Should -Be 'measured'
    }

    It 'leaves the phase blank when nothing was measured and no -Percent is given' {
        $root = Join-Path $TestDrive 'ctx-none'
        $tmp = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $mf = Join-Path $tmp 'WI00007-manifest.json'
        '{"mode":"branch"}' | Set-Content -LiteralPath $mf -Encoding UTF8
        $env:TMO_CTX_USAGE_FILE = Join-Path $TestDrive 'does-not-exist.json'
        try {
            & (Join-Path $PSScriptRoot 'Set-TicketCtxPct.ps1') -Ticket WI00007 -Phase close -Root $root
        } finally {
            Remove-Item Env:TMO_CTX_USAGE_FILE -ErrorAction SilentlyContinue
        }
        $got = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
        $got.PSObject.Properties.Name | Should -Not -Contain 'ctxPct'
    }

    It 'merges reviewReady Ready stamp' {
        $root = Join-Path $TestDrive 'review-root'
        $tmp = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $mf = Join-Path $tmp 'WI00003-manifest.json'
        '{"mode":"branch","affectedRepos":[{"repo":"app","local":true}]}' | Set-Content -LiteralPath $mf -Encoding UTF8
        $script = Join-Path $PSScriptRoot 'Set-ReviewReady.ps1'
        $paths = @{ app = $script:StagedRepo } | ConvertTo-Json -Compress
        & $script -Ticket WI00003 -Mode staged -Verdicts '{"app":"Ready"}' -RepoPaths $paths -Root $root
        $got = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
        $got.reviewReady.mode | Should -Be 'staged'
        $got.reviewReady.repos.app.verdict | Should -Be 'Ready'
        $got.reviewReady.repos.app.fingerprint | Should -Be $script:StagedHash
    }

    It 'refuses a staged Ready stamp when nothing is staged' {
        $root = Join-Path $TestDrive 'review-empty'
        $tmp = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        '{"mode":"branch","affectedRepos":[{"repo":"app","local":true}]}' |
            Set-Content -LiteralPath (Join-Path $tmp 'WI00004-manifest.json') -Encoding UTF8
        $script = Join-Path $PSScriptRoot 'Set-ReviewReady.ps1'
        $paths = @{ app = $script:CleanRepo } | ConvertTo-Json -Compress
        { & $script -Ticket WI00004 -Mode staged -Verdicts '{"app":"Ready"}' -RepoPaths $paths -Root $root } |
            Should -Throw '*Nothing staged*'
    }

    It 'refuses a staged Ready stamp when the repo path does not resolve' {
        $root = Join-Path $TestDrive 'review-unresolved'
        $tmp = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        '{"mode":"branch","affectedRepos":[{"repo":"nope","local":true}]}' |
            Set-Content -LiteralPath (Join-Path $tmp 'WI00005-manifest.json') -Encoding UTF8
        $script = Join-Path $PSScriptRoot 'Set-ReviewReady.ps1'
        { & $script -Ticket WI00005 -Mode staged -Verdicts '{"nope":"Ready"}' -Root $root } |
            Should -Throw '*Nothing staged*'
    }
}
