#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for review skip decisions and ctxPct / reviewReady stamps.
#>

BeforeAll {
    $lib = Join-Path (Join-Path $PSScriptRoot 'lib') 'ManifestFields.ps1'
    . $lib
    $script:EmptyHash = Get-StagedDiffFingerprint -RepoPath ([IO.Path]::GetTempPath())
}

Describe 'Get-ReviewSkipDecision' {
    It 'skips when Ready and fingerprint matches' {
        $stamp = [pscustomobject]@{
            mode  = 'staged'
            repos = [pscustomobject]@{ TmoPro = [pscustomobject]@{ verdict = 'Ready'; fingerprint = $script:EmptyHash } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'TmoPro' -RepoPath ([IO.Path]::GetTempPath())
        $d.skip | Should -Be $true
        $d.reason | Should -Be 'ready-fingerprint-match'
    }

    It 'does not skip Ready with fixes' {
        $stamp = [pscustomobject]@{
            mode  = 'staged'
            repos = [pscustomobject]@{ TmoPro = [pscustomobject]@{ verdict = 'Ready with fixes'; fingerprint = $script:EmptyHash } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'TmoPro' -RepoPath ([IO.Path]::GetTempPath())
        $d.skip | Should -Be $false
        $d.reason | Should -Be 'verdict-not-ready'
    }

    It 'does not skip when fingerprint mismatches' {
        $stamp = [pscustomobject]@{
            mode  = 'staged'
            repos = [pscustomobject]@{ TmoPro = [pscustomobject]@{ verdict = 'Ready'; fingerprint = 'deadbeef' } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'TmoPro' -RepoPath ([IO.Path]::GetTempPath())
        $d.skip | Should -Be $false
        $d.reason | Should -Be 'fingerprint-mismatch'
    }

    It 'does not skip a missing stamp' {
        $d = Get-ReviewSkipDecision -Stamp $null -Repo 'TmoPro' -RepoPath ([IO.Path]::GetTempPath())
        $d.skip | Should -Be $false
        $d.reason | Should -Be 'no-stamp'
    }

    It 'does not skip pre-merge mode' {
        $stamp = [pscustomobject]@{
            mode  = 'pre-merge'
            repos = [pscustomobject]@{ TmoPro = [pscustomobject]@{ verdict = 'Ready'; fingerprint = $script:EmptyHash } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'TmoPro' -RepoPath ([IO.Path]::GetTempPath())
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
    }

    It 'merges reviewReady Ready stamp' {
        $root = Join-Path $TestDrive 'review-root'
        $tmp = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $mf = Join-Path $tmp 'WI00003-manifest.json'
        '{"mode":"branch","affectedRepos":[{"repo":"app","local":true}]}' | Set-Content -LiteralPath $mf -Encoding UTF8
        $script = Join-Path $PSScriptRoot 'Set-ReviewReady.ps1'
        & $script -Ticket WI00003 -Mode staged -Verdicts '{"app":"Ready"}' -Root $root
        $got = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
        $got.reviewReady.mode | Should -Be 'staged'
        $got.reviewReady.repos.app.verdict | Should -Be 'Ready'
        $got.reviewReady.repos.app.fingerprint | Should -Match '^[0-9a-f]{64}$'
    }
}
