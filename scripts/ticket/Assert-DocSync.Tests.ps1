#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for Assert-DocSync.ps1 (docs move with the code they describe).

.DESCRIPTION
    Each test builds a git repo in TestDrive with its own doc-claims.psd1, a base commit
    published as refs/remotes/origin/main, and a branch on top. CI runs Pester with
    GITHUB_ACTIONS (and on PRs GITHUB_BASE_REF) set, so every test clears those first.
    Run: Invoke-Pester ./scripts/ticket/Assert-DocSync.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $script:Gate = Join-Path $PSScriptRoot 'Assert-DocSync.ps1'
    $script:EnvNames = @('GITHUB_ACTIONS', 'GITHUB_BASE_REF', 'DOCSYNC_BASE')

    $script:Registry = @'
@{
    Claims   = @()
    CoChange = @(
        @{
            Id     = 'gates'
            Why    = 'Gate changes are documented.'
            When   = @('scripts/*.ps1')
            Touch  = @('docs/gates.md')
            Ignore = @('*.Tests.ps1')
        }
    )
}
'@

    function Invoke-Git([string]$Repo, [string[]]$GitArgs) {
        & git -C $Repo -c user.email=t@example.com -c user.name=t @GitArgs 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed" }
    }
    function Write-File([string]$Repo, [string]$Rel, [string]$Text) {
        $p = Join-Path $Repo $Rel
        New-Item -ItemType Directory -Path (Split-Path $p -Parent) -Force | Out-Null
        Set-Content -LiteralPath $p -Value $Text -Encoding UTF8
    }
    # A repo whose origin/main is the base commit; the caller adds the branch's changes.
    function New-SyncRepo([string]$Name, [switch]$NoOrigin) {
        $repo = Join-Path $TestDrive $Name
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        Invoke-Git $repo @('init', '-q', '-b', 'main')
        Write-File $repo 'scripts/ticket/doc-claims.psd1' $script:Registry
        Write-File $repo 'scripts/gate.ps1' '# v1'
        Write-File $repo 'docs/gates.md' '# Gates'
        Invoke-Git $repo @('add', '-A')
        Invoke-Git $repo @('commit', '-q', '-m', 'base')
        if (-not $NoOrigin) { Invoke-Git $repo @('update-ref', 'refs/remotes/origin/main', 'HEAD') }
        Invoke-Git $repo @('switch', '-q', '-c', 'feature')
        return $repo
    }
    function Commit-All([string]$Repo, [string]$Message) {
        Invoke-Git $Repo @('add', '-A')
        Invoke-Git $Repo @('commit', '-q', '-m', $Message)
    }
    function Invoke-Sync([string]$Repo, [string[]]$Extra = @()) {
        $out = & pwsh -NoProfile -File $script:Gate -Root $Repo @Extra 2>&1 | Out-String
        return [pscustomobject]@{ Out = $out; Code = $LASTEXITCODE }
    }
}

Describe 'Assert-DocSync' {
    BeforeEach {
        $script:SavedEnv = @{}
        foreach ($n in $script:EnvNames) {
            $script:SavedEnv[$n] = [Environment]::GetEnvironmentVariable($n)
            [Environment]::SetEnvironmentVariable($n, $null)
        }
    }

    AfterEach {
        foreach ($n in $script:EnvNames) { [Environment]::SetEnvironmentVariable($n, $script:SavedEnv[$n]) }
    }

    It 'fails a gate change with no doc change, naming the rule and the file' {
        $repo = New-SyncRepo 'no-doc'
        Write-File $repo 'scripts/gate.ps1' '# v2'
        Commit-All $repo 'change the gate'
        $r = Invoke-Sync $repo
        $r.Code | Should -Be 1
        $r.Out | Should -Match '\[FAIL\] doc-sync: gates -- scripts/gate\.ps1 changed'
        $r.Out | Should -Match "Docs-Unaffected: gates:"
    }

    It 'passes when a mapped doc changed in the same branch' {
        $repo = New-SyncRepo 'with-doc'
        Write-File $repo 'scripts/gate.ps1' '# v2'
        Write-File $repo 'docs/gates.md' '# Gates, updated'
        Commit-All $repo 'change the gate and its doc'
        (Invoke-Sync $repo).Code | Should -Be 0
    }

    It 'counts uncommitted and untracked files, so it fails before the commit' {
        $repo = New-SyncRepo 'untracked'
        Write-File $repo 'scripts/new-gate.ps1' '# new'
        $r = Invoke-Sync $repo
        $r.Code | Should -Be 1
        $r.Out | Should -Match 'scripts/new-gate\.ps1'
    }

    It 'accepts a Docs-Unaffected trailer with a real reason and logs the waiver' {
        $repo = New-SyncRepo 'waived'
        Write-File $repo 'scripts/gate.ps1' '# v2'
        Commit-All $repo "Rename a local variable.`n`nDocs-Unaffected: gates: internal rename, no behavior change"
        $r = Invoke-Sync $repo
        $r.Code | Should -Be 0
        $r.Out | Should -Match '\[INFO\] doc-sync waived [0-9a-f]+ gates: internal rename, no behavior change'
    }

    It 'rejects a thin waiver reason' {
        $repo = New-SyncRepo 'thin-waiver'
        Write-File $repo 'scripts/gate.ps1' '# v2'
        Commit-All $repo "Tweak.`n`nDocs-Unaffected: n/a"
        $r = Invoke-Sync $repo
        $r.Code | Should -Be 1
        $r.Out | Should -Match 'reason is too thin'
    }

    It 'ignores a tests-only change' {
        $repo = New-SyncRepo 'tests-only'
        Write-File $repo 'scripts/gate.Tests.ps1' '# test'
        Commit-All $repo 'add a test'
        (Invoke-Sync $repo).Code | Should -Be 0
    }

    It 'skips with [INFO] outside git or without a base, but fails in CI without a base' {
        $plain = Join-Path $TestDrive 'not-git'
        Write-File $plain 'scripts/ticket/doc-claims.psd1' $script:Registry
        $r = Invoke-Sync $plain
        $r.Code | Should -Be 0
        $r.Out | Should -Match '\[INFO\] doc-sync skipped'

        $repo = New-SyncRepo 'no-origin' -NoOrigin
        Write-File $repo 'scripts/gate.ps1' '# v2'
        Commit-All $repo 'change'
        (Invoke-Sync $repo).Code | Should -Be 0

        [Environment]::SetEnvironmentVariable('GITHUB_ACTIONS', 'true')
        $ci = Invoke-Sync $repo
        $ci.Code | Should -Be 1
        $ci.Out | Should -Match 'CI must have a base'
    }

    It 'uses -Base and DOCSYNC_BASE when given' {
        $repo = New-SyncRepo 'explicit-base' -NoOrigin
        Write-File $repo 'scripts/gate.ps1' '# v2'
        Commit-All $repo 'change'
        (Invoke-Sync $repo @('-Base', 'main')).Code | Should -Be 1

        [Environment]::SetEnvironmentVariable('DOCSYNC_BASE', 'main')
        (Invoke-Sync $repo).Code | Should -Be 1
        [Environment]::SetEnvironmentVariable('DOCSYNC_BASE', '0000000000000000000000000000000000000000')
        (Invoke-Sync $repo).Out | Should -Match 'new branch push'
    }
}
