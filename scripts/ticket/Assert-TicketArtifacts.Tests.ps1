#Requires -Modules Pester
<#
.SYNOPSIS
    Pester tests for the Work Plan content checks in Assert-TicketArtifacts.ps1
    (-Phase start, -CheckDigest block: heading, numbered steps, difficulty tags,
    and the architect requirement on [high] steps).

.DESCRIPTION
    Pester 5 syntax (GitHub Actions installs 5.x). Run with:
    Invoke-Pester ./scripts/ticket/Assert-TicketArtifacts.Tests.ps1 -Output Detailed

    Each test builds a minimal ticket root under $TestDrive (plans/WI00009-manifest.json
    + plans/WI00009-feature-plan.md) and shells out to the real script, the same pattern
    Resolve-TicketRoot.Tests.ps1 uses for its fixture-based Describe blocks.
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'Assert-TicketArtifacts.ps1'
    if (-not (Test-Path -LiteralPath $script:ScriptPath)) {
        throw "Missing Assert-TicketArtifacts.ps1 at $script:ScriptPath - cannot run tests"
    }

    function Get-PowerShell7Path {
        $cmd = Get-Command 'pwsh' -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { return $cmd.Source }
        throw "PowerShell 7 (pwsh) is required. See MACHINE-SETUP.md."
    }
    $script:PwshHost = Get-PowerShell7Path
    $script:Ticket = 'WI00009'
    $script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    # Writes plans/WI00009-manifest.json + plans/WI00009-feature-plan.md under $Root
    # and returns the paths. Every plan body already gets '## Plan Digest' and
    # '## Engineering Decisions' baked in by the caller (spec: "Every plan fixture
    # must also include ## Plan Digest and ## Engineering Decisions so the earlier
    # checks pass") -- callers pass only the Work Plan section (and anything after).
    function New-FixtureRoot {
        param(
            [Parameter(Mandatory)] [string]$Root,
            [Parameter(Mandatory)] [string]$EngineeringDecisions,
            [Parameter(Mandatory)] [string]$WorkPlanSection
        )
        $plansDir = Join-Path $Root 'plans'
        New-Item -ItemType Directory -Path $plansDir -Force | Out-Null

        $manifest = [ordered]@{
            ticket       = $script:Ticket
            mode         = 'branch'
            workType     = 'feature'
            startedAtUtc = '2026-09-01T10:00:00Z'
        }
        $manifestPath = Join-Path $plansDir "$script:Ticket-manifest.json"
        [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), $script:Utf8NoBom)

        $planBody = @"
# $script:Ticket Feature Plan

## Plan Digest

Test fixture for Assert-TicketArtifacts.Tests.ps1.

## Engineering Decisions

$EngineeringDecisions

$WorkPlanSection
"@
        $planPath = Join-Path $plansDir "$script:Ticket-feature-plan.md"
        [System.IO.File]::WriteAllText($planPath, $planBody, $script:Utf8NoBom)

        return @{ Root = $Root; ManifestPath = $manifestPath; PlanPath = $planPath }
    }

    function Invoke-Assert {
        param(
            [Parameter(Mandatory)] [string]$Root,
            [ValidateSet('start', 'implement', 'close')] [string]$Phase = 'start'
        )
        $out = & $script:PwshHost -NonInteractive -NoProfile -File $script:ScriptPath `
            -Ticket $script:Ticket -Phase $Phase -Root $Root 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($out -join "`n")
        }
    }
}

Describe 'Assert-TicketArtifacts -Phase start: Work Plan content checks' {

    It 'passes: plain/bold/backtick/whole-bold tag styles together, indented sub-lists ignored, lowercase "Work plan" heading accepted' {
        $fixture = New-FixtureRoot -Root $TestDrive `
            -EngineeringDecisions 'None -- fixture, no scope or contract calls to make.' `
            -WorkPlanSection @'
## Work plan

1. [low] Fixture step one
2. **[med]** Fixture step two
3. `[low]` Fixture step three
4. **[med] Fixture step four**
   - indented note without a tag
   - another indented note
'@
        $result = Invoke-Assert -Root $fixture.Root -Phase 'start'
        $result.ExitCode | Should -Be 0
    }

    It 'fails: an untagged step, naming the step number' {
        $fixture = New-FixtureRoot -Root $TestDrive `
            -EngineeringDecisions 'None -- fixture, no scope or contract calls to make.' `
            -WorkPlanSection @'
## Work Plan

1. [low] Fixture step one
2. Fixture step two without a tag
'@
        $result = Invoke-Assert -Root $fixture.Root -Phase 'start'
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'Work Plan step\(s\) 2 missing a \[low\]\|\[med\]\|\[high\] tag'
    }

    It 'fails: missing Work Plan heading' {
        $fixture = New-FixtureRoot -Root $TestDrive `
            -EngineeringDecisions 'None -- fixture, no scope or contract calls to make.' `
            -WorkPlanSection @'
## Approach

1. [low] Fixture step one
'@
        $result = Invoke-Assert -Root $fixture.Root -Phase 'start'
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match "missing 'Work Plan' heading"
    }

    It 'fails: a [high] step with Engineering Decisions that never mentions architect' {
        $fixture = New-FixtureRoot -Root $TestDrive `
            -EngineeringDecisions 'None -- fixture, no scope or contract calls to make.' `
            -WorkPlanSection @'
## Work Plan

1. **[high]** Fixture step one
'@
        $result = Invoke-Assert -Root $fixture.Root -Phase 'start'
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'has a \[high\] step but Engineering Decisions records no architect result'
    }

    It 'passes: a [high] step with an explicit "architect skipped: <reason>" in Engineering Decisions' {
        $fixture = New-FixtureRoot -Root $TestDrive `
            -EngineeringDecisions '- architect skipped: single-function fix' `
            -WorkPlanSection @'
## Work Plan

1. **[high]** Fixture step one
'@
        $result = Invoke-Assert -Root $fixture.Root -Phase 'start'
        $result.ExitCode | Should -Be 0
    }
}

Describe 'Assert-TicketArtifacts -Phase implement: not retroactive' {
    It 'passes on a plan with an untagged Work Plan step -- implement does not re-check plan content' {
        # -Phase implement runs Test-Manifest + Test-PlanFile (existence only, no
        # -CheckDigest), so the same untagged plan that fails -Phase start above must
        # still pass here: a plan approved before the tag requirement existed (or, in
        # this repo, before the Work Plan checks existed at all) must not retroactively
        # fail implement.
        $fixture = New-FixtureRoot -Root $TestDrive `
            -EngineeringDecisions 'None -- fixture, no scope or contract calls to make.' `
            -WorkPlanSection @'
## Work Plan

1. [low] Fixture step one
2. Fixture step two without a tag
'@
        $result = Invoke-Assert -Root $fixture.Root -Phase 'implement'
        $result.ExitCode | Should -Be 0
    }
}

Describe 'Assert-TicketArtifacts -Phase close: context percents' {
    BeforeAll {
    function New-CloseRoot {
        param(
            [Parameter(Mandatory)][string]$Root,
            [Parameter(Mandatory)][string]$WorkType,
            [hashtable]$Ctx,
            [bool]$ReviewSkipped = $false
        )
        $plans = Join-Path $Root 'plans'
        New-Item -ItemType Directory -Path $plans -Force | Out-Null
        $manifest = [ordered]@{
            ticket         = 'WI00009'
            mode           = 'branch'
            workType       = $WorkType
            startedAtUtc   = '2026-09-01T10:00:00Z'
            completedAtUtc = '2026-09-02T10:00:00Z'
        }
        if ($ReviewSkipped) { $manifest.reviewSkipped = $true }
        if ($Ctx) { $manifest.ctxPct = $Ctx }
        if ($WorkType -ne 'spike') {
            $manifest.verify = @{ repos = @{ app = @{ pass = $true; tests = 'pass'; sonar = 'ok' } } }
        }
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText((Join-Path $plans 'WI00009-manifest.json'), ($manifest | ConvertTo-Json -Depth 6), $utf8)
        $ledger = @(
            '# Ticket ledger'
            ''
            '| Ticket | Type |'
            '|---|---|'
            '| WI00009 | bug |'
        ) -join "`n"
        [System.IO.File]::WriteAllText((Join-Path $plans 'ticket-ledger.md'), $ledger + "`n", $utf8)
    }

    # Adds top-level fields to the WI00009 manifest under $Root.
    function Add-ManifestFields([string]$Root, [hashtable]$Fields) {
        $manifestPath = Join-Path $Root 'plans/WI00009-manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        foreach ($k in $Fields.Keys) { $manifest | Add-Member -NotePropertyName $k -NotePropertyValue $Fields[$k] -Force }
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8) + "`n", $utf8)
    }

    # Replaces manifest.verify with the given JSON object.
    function Set-VerifyJson([string]$Root, [string]$Json) {
        Add-ManifestFields $Root @{ verify = ($Json | ConvertFrom-Json) }
    }

    # One affected repo 'app' with no local path, so the stamp is checked as JSON only.
    function New-StampedCloseRoot([string]$Root, [string]$Verdict = 'Ready') {
        New-CloseRoot -Root $Root -WorkType 'bug' -Ctx @{ start = 40; review = 50; close = 60 }
        $entry = [pscustomobject]@{ verdict = $Verdict; mode = 'staged'; fingerprint = ('ab' * 32); fpVersion = 2 }
        Add-ManifestFields $Root @{
            affectedRepos = @([pscustomobject]@{ repo = 'app'; local = $true })
            reviewReady   = [pscustomobject]@{ mode = 'staged'; repos = [pscustomobject]@{ app = $entry } }
        }
    }
    }

    It 'passes when ctxPct.start was not measured (blank is honest)' {
        $root = Join-Path $TestDrive 'close-no-start'
        New-CloseRoot -Root $root -WorkType 'bug' -Ctx @{ close = 10; review = 10 }
        $result = Invoke-Assert -Root $root -Phase 'close'
        $result.ExitCode | Should -Be 0
    }

    It 'fails when a recorded ctxPct is not 0-100' {
        $root = Join-Path $TestDrive 'close-bad-start'
        New-CloseRoot -Root $root -WorkType 'bug' -Ctx @{ start = 140; close = 10; review = 10 }
        $result = Invoke-Assert -Root $root -Phase 'close'
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'ctxPct.start'
    }

    It 'passes when start, review, and close are 0-100' {
        $root = Join-Path $TestDrive 'close-ok'
        New-CloseRoot -Root $root -WorkType 'bug' -Ctx @{ start = 40; review = 50; close = 60 }
        $result = Invoke-Assert -Root $root -Phase 'close'
        $result.ExitCode | Should -Be 0
    }

    It 'passes a spike without ctxPct.review' {
        $root = Join-Path $TestDrive 'close-spike'
        New-CloseRoot -Root $root -WorkType 'spike' -Ctx @{ start = 20; close = 30 }
        $result = Invoke-Assert -Root $root -Phase 'close'
        $result.ExitCode | Should -Be 0
    }

    It 'passes a bug close without optional stackSmoke' {
        $root = Join-Path $TestDrive 'close-no-smoke'
        New-CloseRoot -Root $root -WorkType 'bug' -Ctx @{ start = 40; review = 50; close = 60 }
        $result = Invoke-Assert -Root $root -Phase 'close'
        $result.ExitCode | Should -Be 0
        $result.Output | Should -Not -Match 'stackSmoke'
    }

    It 'passes a bug close when stackSmoke is present' {
        $root = Join-Path $TestDrive 'close-with-smoke'
        New-CloseRoot -Root $root -WorkType 'bug' -Ctx @{ start = 40; review = 50; close = 60 }
        $manifestPath = Join-Path $root 'plans/WI00009-manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest | Add-Member -NotePropertyName stackSmoke -NotePropertyValue ([pscustomobject]@{ status = 'passed'; notes = 'fixture' })
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 6) + "`n", $utf8)
        $result = Invoke-Assert -Root $root -Phase 'close'
        $result.ExitCode | Should -Be 0
    }
    It 'fails a bug close with no verify results on the manifest' {
        $root = Join-Path $TestDrive 'close-no-verify'
        New-CloseRoot -Root $root -WorkType 'bug' -Ctx @{ start = 40; review = 50; close = 60 }
        $manifestPath = Join-Path $root 'plans/WI00009-manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest.PSObject.Properties.Remove('verify')
        [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
        $result = Invoke-Assert -Root $root -Phase 'close'
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'verify'
    }

    It 'fails when an affected repo has no review fingerprint' {
        $root = Join-Path $TestDrive 'close-no-fp'
        New-CloseRoot -Root $root -WorkType 'bug' -Ctx @{ start = 40; review = 50; close = 60 }
        $manifestPath = Join-Path $root 'plans/WI00009-manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest | Add-Member -NotePropertyName affectedRepos -NotePropertyValue @([pscustomobject]@{ repo = 'app'; local = $true })
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 6) + "`n", $utf8)
        $result = Invoke-Assert -Root $root -Phase 'close'
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'no review stamp'
    }

    It 'fails when the repo path exists and the fingerprint does not match the commit' {
        $root = Join-Path $TestDrive 'close-mismatch'
        $repo = Join-Path $root 'app'
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        & git -C $repo init -q
        & git -C $repo config user.email 't@example.com'
        & git -C $repo config user.name 't'
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'one'
        & git -C $repo add a.txt
        & git -C $repo commit -q -m init
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'two'
        & git -C $repo add a.txt
        & git -C $repo commit -q -m change
        New-CloseRoot -Root $root -WorkType 'bug' -Ctx @{ start = 40; review = 50; close = 60 }
        $manifestPath = Join-Path $root 'plans/WI00009-manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $stamp = [pscustomobject]@{
            mode  = 'staged'
            repos = [pscustomobject]@{
                app = [pscustomobject]@{
                    verdict     = 'Ready'
                    fingerprint = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
                }
            }
        }
        $manifest | Add-Member -NotePropertyName affectedRepos -NotePropertyValue @([pscustomobject]@{ repo = 'app'; local = $true; path = $repo })
        $manifest | Add-Member -NotePropertyName reviewReady -NotePropertyValue $stamp
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8) + "`n", $utf8)
        $result = Invoke-Assert -Root $root -Phase 'close'
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'does not match'
    }

    It 'passes a stamped repo with a passing verify entry' {
        $root = Join-Path $TestDrive 'close-stamped'
        New-StampedCloseRoot $root
        (Invoke-Assert -Root $root -Phase 'close').ExitCode | Should -Be 0
    }

    It 'fails a stamp whose verdict is <verdict>' -ForEach @(
        @{ verdict = 'Not ready' }
        @{ verdict = '' }
    ) {
        $root = Join-Path $TestDrive "close-verdict-$($verdict.Length)"
        New-StampedCloseRoot $root -Verdict $verdict
        $result = Invoke-Assert -Root $root -Phase 'close'
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'needs Ready'
    }

    It 'fails a verify entry whose pass is the string <value>' -ForEach @(
        @{ value = 'false' }
        @{ value = 'true' }
    ) {
        $root = Join-Path $TestDrive "close-pass-string-$value"
        New-StampedCloseRoot $root
        Set-VerifyJson $root "{ `"repos`": { `"app`": { `"pass`": `"$value`" } } }"
        $result = Invoke-Assert -Root $root -Phase 'close'
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'boolean true'
    }

    It 'fails when verify has no entry for an affected repo' {
        $root = Join-Path $TestDrive 'close-receipt-missing-repo'
        New-StampedCloseRoot $root
        Set-VerifyJson $root '{ "repos": { "other": { "pass": true } } }'
        $result = Invoke-Assert -Root $root -Phase 'close'
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'verify.repos.app -- missing'
    }

    It 'passes a verify entry whose tests were not run, with a reason' {
        $root = Join-Path $TestDrive 'close-receipt-not-run'
        New-StampedCloseRoot $root
        Set-VerifyJson $root '{ "repos": { "app": { "pass": true, "tests": "not-run", "reason": "docs-only" } } }'
        (Invoke-Assert -Root $root -Phase 'close').ExitCode | Should -Be 0
    }

    It 'end to end: stamp, commit, base merge, receipt passes; a later commit fails' {
        $root = Join-Path $TestDrive 'close-e2e'
        $repo = Join-Path $root 'app'
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        & git -C $repo init -q -b main
        & git -C $repo config user.email 't@example.com'
        & git -C $repo config user.name 't'
        & git -C $repo config commit.gpgsign false
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'one'
        & git -C $repo add a.txt
        & git -C $repo commit -q -m init
        & git -C $repo branch dev
        New-CloseRoot -Root $root -WorkType 'bug' -Ctx @{ start = 40; review = 50; close = 60 }
        Add-ManifestFields $root @{ affectedRepos = @([pscustomobject]@{ repo = 'app'; local = $true; path = $repo }) }

        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'two'
        & git -C $repo add a.txt
        $paths = @{ app = $repo } | ConvertTo-Json -Compress
        & (Join-Path $PSScriptRoot 'Set-ReviewReady.ps1') -Ticket WI00009 -Mode staged -Verdicts '{"app":"Ready"}' -RepoPaths $paths -Root $root
        & git -C $repo commit -q -m change
        & git -C $repo checkout -q dev
        Set-Content -LiteralPath (Join-Path $repo 'dev.txt') -Value 'dev'
        & git -C $repo add dev.txt
        & git -C $repo commit -q -m dev
        & git -C $repo checkout -q main
        & git -C $repo merge -q --no-ff dev -m 'merge dev' 2>$null | Out-Null
        & (Join-Path $PSScriptRoot 'Set-VerifyReceipt.ps1') -Ticket WI00009 -Repo app -Tests pass -Sonar not-run -RepoPath $repo -Root $root

        (Invoke-Assert -Root $root -Phase 'close').ExitCode | Should -Be 0

        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'three'
        & git -C $repo add a.txt
        & git -C $repo commit -q -m 'unreviewed'
        $result = Invoke-Assert -Root $root -Phase 'close'
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 're-review'
    }

    It 'passes a legacy stamp (no headSha) that matches the last commit' {
        $root = Join-Path $TestDrive 'close-match'
        $repo = Join-Path $root 'app'
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        & git -C $repo init -q
        & git -C $repo config user.email 't@example.com'
        & git -C $repo config user.name 't'
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'one'
        & git -C $repo add a.txt
        & git -C $repo commit -q -m init
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'two'
        & git -C $repo add a.txt
        & git -C $repo commit -q -m change
        . (Join-Path $PSScriptRoot 'lib/ManifestFields.ps1')
        $fp = Get-WorkDiffFingerprint -RepoPath $repo -Version 1
        New-CloseRoot -Root $root -WorkType 'bug' -Ctx @{ start = 40; review = 50; close = 60 }
        $manifestPath = Join-Path $root 'plans/WI00009-manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $stamp = [pscustomobject]@{
            mode  = 'staged'
            repos = [pscustomobject]@{
                app = [pscustomobject]@{
                    verdict     = 'Ready'
                    fingerprint = $fp
                }
            }
        }
        $manifest | Add-Member -NotePropertyName affectedRepos -NotePropertyValue @([pscustomobject]@{ repo = 'app'; local = $true; path = $repo })
        $manifest | Add-Member -NotePropertyName reviewReady -NotePropertyValue $stamp
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8) + "`n", $utf8)
        $result = Invoke-Assert -Root $root -Phase 'close'
        $result.ExitCode | Should -Be 0
    }
}
