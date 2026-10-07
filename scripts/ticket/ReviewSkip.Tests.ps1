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
            repos = [pscustomobject]@{ app = [pscustomobject]@{ verdict = 'Ready'; fingerprint = $script:StagedHash; fpVersion = 2 } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'app' -RepoPath $script:StagedRepo
        $d.skip | Should -Be $true
        $d.reason | Should -Be 'staged-match'
    }

    It 'does not skip Ready with fixes' {
        $stamp = [pscustomobject]@{
            mode  = 'staged'
            repos = [pscustomobject]@{ app = [pscustomobject]@{ verdict = 'Ready with fixes'; fingerprint = $script:StagedHash; fpVersion = 2 } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'app' -RepoPath $script:StagedRepo
        $d.skip | Should -Be $false
        $d.reason | Should -Be 'verdict-not-ready'
    }

    It 'does not skip when fingerprint mismatches' {
        $stamp = [pscustomobject]@{
            mode  = 'staged'
            repos = [pscustomobject]@{ app = [pscustomobject]@{ verdict = 'Ready'; fingerprint = 'deadbeef' } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'app' -RepoPath $script:StagedRepo
        $d.skip | Should -Be $false
        $d.reason | Should -Match '^work-changed: staged diff differs'
    }

    It 'does not skip a stamp of the empty diff, even when nothing is staged now' {
        $stamp = [pscustomobject]@{
            mode  = 'staged'
            repos = [pscustomobject]@{ app = [pscustomobject]@{ verdict = 'Ready'; fingerprint = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'app' -RepoPath $script:CleanRepo
        $d.skip | Should -Be $false
        $d.reason | Should -Be 'empty-stamp'
    }

    It 'does not skip when the staged set is now empty' {
        $stamp = [pscustomobject]@{
            mode  = 'staged'
            repos = [pscustomobject]@{ app = [pscustomobject]@{ verdict = 'Ready'; fingerprint = $script:StagedHash; fpVersion = 2 } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'app' -RepoPath $script:CleanRepo
        $d.skip | Should -Be $false
        $d.reason | Should -Match '^work-changed'
    }

    It 'does not skip a missing stamp' {
        $d = Get-ReviewSkipDecision -Stamp $null -Repo 'app' -RepoPath ([IO.Path]::GetTempPath())
        $d.skip | Should -Be $false
        $d.reason | Should -Be 'no-stamp'
    }

    It 'does not skip a pre-merge stamp while something is staged' {
        $stamp = [pscustomobject]@{
            mode  = 'pre-merge'
            repos = [pscustomobject]@{ app = [pscustomobject]@{ verdict = 'Ready'; fingerprint = $script:StagedHash; fpVersion = 2 } }
        }
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'app' -RepoPath $script:StagedRepo
        $d.skip | Should -Be $false
        $d.reason | Should -Match 'staged change after the review'
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

Describe 'Test-ReviewedWorkPresent' {
    BeforeAll {
        $script:Seq = 0
        # main with one commit, and a dev branch at the same point for the base-branch merge.
        function New-WorkRepo([string]$Path) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            & git -C $Path init -q -b main
            & git -C $Path config user.email 't@example.com'
            & git -C $Path config user.name 't'
            & git -C $Path config commit.gpgsign false
            Set-Content -LiteralPath (Join-Path $Path 'a.txt') -Value 'one'
            & git -C $Path add a.txt
            & git -C $Path commit -q -m init
            & git -C $Path branch dev
        }
        function Set-Staged([string]$Path, [string]$File, [string]$Text) {
            Set-Content -LiteralPath (Join-Path $Path $File) -Value $Text
            & git -C $Path add $File
        }
        function Save-Commit([string]$Path, [string]$File, [string]$Text) {
            Set-Staged $Path $File $Text
            & git -C $Path commit -q -m "edit $File"
        }
        # What Set-ReviewReady writes for the current staged set.
        function New-StagedEntry([string]$Path) {
            [pscustomobject]@{
                verdict     = 'Ready'
                mode        = 'staged'
                headSha     = (Get-GitHeadSha -RepoPath $Path)
                fingerprint = (Get-StagedDiffFingerprint -RepoPath $Path)
                fpVersion   = 2
            }
        }
        # prep-pr merges the base branch before push: a dev commit merged with --no-ff.
        function Merge-BaseBranch([string]$Path) {
            $script:Seq++
            & git -C $Path checkout -q dev
            Save-Commit $Path "dev$($script:Seq).txt" 'dev work'
            & git -C $Path checkout -q main
            & git -C $Path merge -q --no-ff dev -m 'merge dev' 2>$null | Out-Null
        }
    }

    It 'gives the same version-2 hash under diff.mnemonicPrefix and a longer core.abbrev' {
        $repo = Join-Path $TestDrive 'rw-stable'
        New-WorkRepo $repo
        Set-Staged $repo 'a.txt' 'two'
        $before = Get-StagedDiffFingerprint -RepoPath $repo
        & git -C $repo config diff.mnemonicPrefix true
        & git -C $repo config core.abbrev 20
        Get-StagedDiffFingerprint -RepoPath $repo | Should -Be $before
        $head = Get-GitHeadSha -RepoPath $repo
        & git -C $repo commit -q -m change
        Get-RangeDiffFingerprint -RepoPath $repo -From $head -To 'HEAD' | Should -Be $before
    }

    It 'passes after commit and a base-branch merge' {
        $repo = Join-Path $TestDrive 'rw-merge'
        New-WorkRepo $repo
        Set-Staged $repo 'a.txt' 'two'
        $entry = New-StagedEntry $repo
        & git -C $repo commit -q -m change
        Merge-BaseBranch $repo
        (Test-ReviewedWorkPresent -RepoPath $repo -Entry $entry).ok | Should -BeTrue
    }

    It 'fails when a base merge commit contains edits beyond both parents' {
        $repo = Join-Path $TestDrive 'rw-merge-conflict'
        New-WorkRepo $repo
        Set-Staged $repo 'a.txt' 'two'
        $entry = New-StagedEntry $repo
        & git -C $repo commit -q -m change
        & git -C $repo checkout -q dev
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'dev side'
        & git -C $repo add a.txt
        & git -C $repo commit -q -m 'dev side'
        & git -C $repo checkout -q main
        & git -C $repo merge --no-ff dev -m 'merge dev' 2>$null | Out-Null
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'resolved third'
        & git -C $repo add a.txt
        & git -C $repo commit -q -m 'merge with edit'
        $r = Test-ReviewedWorkPresent -RepoPath $repo -Entry $entry
        $r.ok | Should -BeFalse
        $r.reason | Should -Match 'stamp -Mode pre-merge'
    }

    It 'fails when a commit lands after the review' {
        $repo = Join-Path $TestDrive 'rw-edit'
        New-WorkRepo $repo
        Set-Staged $repo 'a.txt' 'two'
        $entry = New-StagedEntry $repo
        & git -C $repo commit -q -m change
        Merge-BaseBranch $repo
        Save-Commit $repo 'a.txt' 'three'
        $r = Test-ReviewedWorkPresent -RepoPath $repo -Entry $entry
        $r.ok | Should -BeFalse
        $r.reason | Should -Match 'differs'
    }

    It 'fails when a new edit is staged after the review' {
        $repo = Join-Path $TestDrive 'rw-staged-edit'
        New-WorkRepo $repo
        Set-Staged $repo 'a.txt' 'two'
        $entry = New-StagedEntry $repo
        Set-Staged $repo 'b.txt' 'extra'
        (Test-ReviewedWorkPresent -RepoPath $repo -Entry $entry).ok | Should -BeFalse
    }

    It 'passes when the reviewed set is split across two commits' {
        $repo = Join-Path $TestDrive 'rw-split'
        New-WorkRepo $repo
        Set-Staged $repo 'a.txt' 'two'
        Set-Staged $repo 'b.txt' 'new'
        $entry = New-StagedEntry $repo
        & git -C $repo reset -q -- b.txt
        & git -C $repo commit -q -m 'part one'
        & git -C $repo add b.txt
        & git -C $repo commit -q -m 'part two'
        (Test-ReviewedWorkPresent -RepoPath $repo -Entry $entry).ok | Should -BeTrue
    }

    It 'passes No change until a commit lands' {
        $repo = Join-Path $TestDrive 'rw-nochange'
        New-WorkRepo $repo
        $entry = [pscustomobject]@{ verdict = 'No change'; mode = 'staged'; headSha = (Get-GitHeadSha -RepoPath $repo); fingerprint = $null; fpVersion = 2 }
        Merge-BaseBranch $repo
        (Test-ReviewedWorkPresent -RepoPath $repo -Entry $entry).ok | Should -BeTrue
        Save-Commit $repo 'a.txt' 'surprise'
        (Test-ReviewedWorkPresent -RepoPath $repo -Entry $entry).ok | Should -BeFalse
    }

    It 'passes a pre-merge stamp through a base merge, and fails on a new commit or a rebase' {
        $repo = Join-Path $TestDrive 'rw-premerge'
        New-WorkRepo $repo
        Save-Commit $repo 'a.txt' 'two'
        $entry = [pscustomobject]@{ verdict = 'Ready'; mode = 'pre-merge'; headSha = (Get-GitHeadSha -RepoPath $repo); fingerprint = $null; fpVersion = 2 }
        Merge-BaseBranch $repo
        (Test-ReviewedWorkPresent -RepoPath $repo -Entry $entry).ok | Should -BeTrue
        Save-Commit $repo 'a.txt' 'three'
        (Test-ReviewedWorkPresent -RepoPath $repo -Entry $entry).ok | Should -BeFalse
        & git -C $repo reset -q --hard HEAD~3
        Save-Commit $repo 'a.txt' 'rewritten'
        $r = Test-ReviewedWorkPresent -RepoPath $repo -Entry $entry
        $r.ok | Should -BeFalse
        $r.reason | Should -Match 'not on this branch'
    }

    It 'passes when the base is merged between two work commits' {
        $repo = Join-Path $TestDrive 'rw-merge-between'
        New-WorkRepo $repo
        Set-Staged $repo 'a.txt' 'two'
        Set-Staged $repo 'b.txt' 'new'
        $entry = New-StagedEntry $repo
        & git -C $repo reset -q -- b.txt
        & git -C $repo commit -q -m 'part one'
        Merge-BaseBranch $repo
        & git -C $repo add b.txt
        & git -C $repo commit -q -m 'part two'
        $r = Test-ReviewedWorkPresent -RepoPath $repo -Entry $entry
        $r.ok | Should -BeTrue
        $r.reason | Should -Be 'commit-match-replayed'
    }

    It 'fails when the base is merged between work commits and the later commit is not what was reviewed' {
        $repo = Join-Path $TestDrive 'rw-merge-between-edit'
        New-WorkRepo $repo
        Set-Staged $repo 'a.txt' 'two'
        $entry = New-StagedEntry $repo
        & git -C $repo commit -q -m 'reviewed'
        Merge-BaseBranch $repo
        Save-Commit $repo 'c.txt' 'unreviewed'
        $r = Test-ReviewedWorkPresent -RepoPath $repo -Entry $entry
        $r.ok | Should -BeFalse
        $r.reason | Should -Match 'differs'
    }

    It 'skip and close agree: No change is not skipped once a commit lands' {
        $repo = Join-Path $TestDrive 'rw-skip-nochange'
        New-WorkRepo $repo
        $entry = [pscustomobject]@{ verdict = 'No change'; mode = 'staged'; headSha = (Get-GitHeadSha -RepoPath $repo); fingerprint = $null; fpVersion = 2 }
        $stamp = [pscustomobject]@{ mode = 'staged'; repos = [pscustomobject]@{ app = $entry } }
        (Get-ReviewSkipDecision -Stamp $stamp -Repo 'app' -RepoPath $repo).skip | Should -BeTrue
        Save-Commit $repo 'a.txt' 'surprise'
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'app' -RepoPath $repo
        $d.skip | Should -BeFalse
        $d.reason | Should -Match 'commit\(s\) after the review'
        (Test-ReviewedWorkPresent -RepoPath $repo -Entry $entry).ok | Should -BeFalse
    }

    It 'skip and close agree: a staged Ready entry is skipped after its work is committed' {
        $repo = Join-Path $TestDrive 'rw-skip-committed'
        New-WorkRepo $repo
        Set-Staged $repo 'a.txt' 'two'
        $stamp = [pscustomobject]@{ mode = 'staged'; repos = [pscustomobject]@{ app = (New-StagedEntry $repo) } }
        & git -C $repo commit -q -m change
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'app' -RepoPath $repo
        $d.skip | Should -BeTrue
        $d.reason | Should -Be 'commit-match'
    }

    It 'skips a pre-merge Ready stamp while the branch is unchanged' {
        $repo = Join-Path $TestDrive 'rw-skip-premerge'
        New-WorkRepo $repo
        Save-Commit $repo 'a.txt' 'two'
        $entry = [pscustomobject]@{ verdict = 'Ready'; mode = 'pre-merge'; headSha = (Get-GitHeadSha -RepoPath $repo); fingerprint = $null; fpVersion = 2 }
        $stamp = [pscustomobject]@{ mode = 'pre-merge'; repos = [pscustomobject]@{ app = $entry } }
        Merge-BaseBranch $repo
        $d = Get-ReviewSkipDecision -Stamp $stamp -Repo 'app' -RepoPath $repo
        $d.skip | Should -BeTrue
        $d.reason | Should -Be 'pre-merge-head'
    }

    It 'passes a legacy stamp (no headSha) after a base-branch merge' {
        $repo = Join-Path $TestDrive 'rw-legacy'
        New-WorkRepo $repo
        Save-Commit $repo 'a.txt' 'two'
        $entry = [pscustomobject]@{ verdict = 'Ready'; fingerprint = (Get-WorkDiffFingerprint -RepoPath $repo -Version 1) }
        Merge-BaseBranch $repo
        (Test-ReviewedWorkPresent -RepoPath $repo -Entry $entry).ok | Should -BeTrue
    }
}

Describe 'Set-ReviewReady entries' {
    It 'upserts one repo and keeps the others, with headSha and fpVersion' {
        $root = Join-Path $TestDrive 'review-upsert'
        $tmp = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $mf = Join-Path $tmp 'WI00011-manifest.json'
        '{"mode":"branch","reviewReady":{"mode":"staged","repos":{"other":{"verdict":"Ready","fingerprint":"abc"}}}}' |
            Set-Content -LiteralPath $mf -Encoding UTF8
        $paths = @{ app = $script:StagedRepo } | ConvertTo-Json -Compress
        & (Join-Path $PSScriptRoot 'Set-ReviewReady.ps1') -Ticket WI00011 -Mode staged -Verdicts '{"app":"Ready"}' -RepoPaths $paths -Root $root
        $got = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
        $got.reviewReady.repos.other.verdict | Should -Be 'Ready'
        $got.reviewReady.repos.other.mode | Should -Be 'staged'
        $got.reviewReady.repos.app.headSha | Should -Match '^[0-9a-f]{40}$'
        $got.reviewReady.repos.app.fpVersion | Should -Be 2
    }

    It 'refuses No change when something is staged' {
        $root = Join-Path $TestDrive 'review-nochange-staged'
        $tmp = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        '{"mode":"branch"}' | Set-Content -LiteralPath (Join-Path $tmp 'WI00012-manifest.json') -Encoding UTF8
        $paths = @{ app = $script:StagedRepo } | ConvertTo-Json -Compress
        { & (Join-Path $PSScriptRoot 'Set-ReviewReady.ps1') -Ticket WI00012 -Mode staged -Verdicts '{"app":"No change"}' -RepoPaths $paths -Root $root } |
            Should -Throw '*staged changes*'
    }

    It 'stamps No change on a clean repo' {
        $root = Join-Path $TestDrive 'review-nochange'
        $tmp = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $mf = Join-Path $tmp 'WI00013-manifest.json'
        '{"mode":"branch"}' | Set-Content -LiteralPath $mf -Encoding UTF8
        $paths = @{ app = $script:CleanRepo } | ConvertTo-Json -Compress
        & (Join-Path $PSScriptRoot 'Set-ReviewReady.ps1') -Ticket WI00013 -Mode staged -Verdicts '{"app":"No change"}' -RepoPaths $paths -Root $root
        $got = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
        $got.reviewReady.repos.app.verdict | Should -Be 'No change'
        $got.reviewReady.repos.app.fingerprint | Should -BeNullOrEmpty
    }
}
