#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for the manifest writers that replace per-ticket side files:
    Set-VerifyReceipt.ps1 (manifest.verify), Set-ReviewReady.ps1 -Findings
    (reviewReady.repos.<repo>.findings), and Set-TicketFeedback.ps1 (manifest.feedback).
#>

BeforeAll {
    $script:Verify = Join-Path $PSScriptRoot 'Set-VerifyReceipt.ps1'
    $script:Feedback = Join-Path $PSScriptRoot 'Set-TicketFeedback.ps1'
    $script:FeedbackForwarder = Join-Path (Split-Path $PSScriptRoot -Parent) 'Set-TicketFeedback.ps1'
    function New-ManifestRoot([string]$Name) {
        $root = Join-Path $TestDrive $Name
        $plans = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $plans -Force | Out-Null
        '{"mode":"branch"}' | Set-Content -LiteralPath (Join-Path $plans 'WI00020-manifest.json') -Encoding UTF8
        return $root
    }
    function Get-Manifest([string]$Root) {
        return (Get-Content -LiteralPath (Join-Path $Root 'plans/WI00020-manifest.json') -Raw | ConvertFrom-Json)
    }
}

Describe 'Set-VerifyReceipt' {
    It 'writes one entry per repo on the manifest and replaces a repo on a second call' {
        $root = New-ManifestRoot 'upsert'
        & $script:Verify -Ticket WI00020 -Repo app -Tests fail -Sonar ok -Failing 'SomeTest' -Root $root
        & $script:Verify -Ticket WI00020 -Repo api -Tests pass -Sonar ok -Root $root
        & $script:Verify -Ticket WI00020 -Repo app -Tests pass -Sonar ok -Root $root
        $got = (Get-Manifest $root).verify.repos
        @($got.PSObject.Properties).Count | Should -Be 2
        $got.app.pass | Should -BeTrue
        $got.api.pass | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $root 'plans/WI00020-verify.json') | Should -BeFalse
    }

    It 'records pass false for failing tests, a failing name, or a Sonar error' -ForEach @(
        @{ tests = 'fail'; sonar = 'ok'; failing = @() }
        @{ tests = 'pass'; sonar = 'error'; failing = @() }
        @{ tests = 'pass'; sonar = 'ok'; failing = @('Flaky') }
    ) {
        $root = New-ManifestRoot "fail-$tests-$sonar-$($failing.Count)"
        & $script:Verify -Ticket WI00020 -Repo app -Tests $tests -Sonar $sonar -Failing $failing -Root $root
        $entry = (Get-Manifest $root).verify.repos.app
        $entry.pass | Should -BeFalse
        $entry.pass | Should -BeOfType [bool]
    }

    It 'refuses not-run tests without a reason' {
        $root = New-ManifestRoot 'not-run'
        { & $script:Verify -Ticket WI00020 -Repo app -Tests not-run -Sonar not-run -Root $root } |
            Should -Throw '*-Reason*'
    }

    It 'passes not-run tests with a reason' {
        $root = New-ManifestRoot 'not-run-reason'
        & $script:Verify -Ticket WI00020 -Repo app -Tests not-run -Sonar not-run -Reason 'docs-only' -Root $root
        $entry = (Get-Manifest $root).verify.repos.app
        $entry.pass | Should -BeTrue
        $entry.reason | Should -Be 'docs-only'
    }

    It 'records the work it ran on: staged fingerprint, headSha, and mode' {
        $root = New-ManifestRoot 'work-identity'
        $repo = Join-Path $TestDrive 'receipt-repo'
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        & git -C $repo init -q
        & git -C $repo config user.email 't@example.com'
        & git -C $repo config user.name 't'
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'one'
        & git -C $repo add a.txt
        & git -C $repo commit -q -m init
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'two'
        & git -C $repo add a.txt
        & $script:Verify -Ticket WI00020 -Repo app -Tests pass -Sonar ok -RepoPath $repo -Root $root
        $entry = (Get-Manifest $root).verify.repos.app
        $entry.mode | Should -Be 'staged'
        $entry.fingerprint | Should -Match '^[0-9a-f]{64}$'
        $entry.fpVersion | Should -Be 2
        $entry.headSha | Should -Match '^[0-9a-f]{40}$'
    }

    It 'refuses a ticket with no manifest' {
        $root = Join-Path $TestDrive 'no-manifest'
        New-Item -ItemType Directory -Path (Join-Path $root 'plans') -Force | Out-Null
        { & $script:Verify -Ticket WI00020 -Repo app -Tests pass -Sonar ok -Root $root } | Should -Throw '*Manifest not found*'
    }
}

Describe 'Set-ReviewReady -Findings' {
    It 'stores at most ten trimmed findings on the repo entry' {
        $root = New-ManifestRoot 'findings'
        $repo = Join-Path $TestDrive 'findings-repo'
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        & git -C $repo init -q
        & git -C $repo config user.email 't@example.com'
        & git -C $repo config user.name 't'
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'one'
        & git -C $repo add a.txt
        $many = @(1..12 | ForEach-Object { " Major: finding $_ " }) | ConvertTo-Json -Compress
        $paths = @{ app = $repo } | ConvertTo-Json -Compress
        & (Join-Path $PSScriptRoot 'Set-ReviewReady.ps1') -Ticket WI00020 -Mode staged -Verdicts '{"app":"Ready with fixes"}' `
            -Findings "{`"app`":$many}" -RepoPaths $paths -Root $root
        $entry = (Get-Manifest $root).reviewReady.repos.app
        @($entry.findings).Count | Should -Be 10
        $entry.findings[0] | Should -Be 'Major: finding 1'
        Get-ChildItem -LiteralPath $repo -Recurse -Force -File | ForEach-Object { $_.IsReadOnly = $false }
    }
}

Describe 'Set-TicketFeedback' {
    It 'writes feedback from the pipeline and stamps fetchedAtUtc' {
        $root = New-ManifestRoot 'feedback'
        $json = '{ "prs": [ { "repo": "app", "id": 7, "status": "Active" } ], "items": [ { "kind": "thread", "repo": "app", "pr": 7, "ref": "101", "ask": "Rename the helper.", "triage": "fix-now" } ] }'
        $json | & $script:Feedback -Ticket WI00020 -Root $root
        $fb = (Get-Manifest $root).feedback
        $fb.items[0].triage | Should -Be 'fix-now'
        $fb.fetchedAtUtc | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath (Join-Path $root 'plans/WI00020-feedback.md') | Should -BeFalse
    }

    It 'takes -Json through the top-level forwarder with nothing piped in' {
        $root = New-ManifestRoot 'feedback-forwarder-param'
        $json = '{ "prs": [], "items": [ { "kind": "thread", "ref": "1", "ask": "Rename it.", "triage": "fix-now" } ] }'
        & $script:FeedbackForwarder -Ticket WI00020 -Json $json -Root $root
        (Get-Manifest $root).feedback.items[0].ask | Should -Be 'Rename it.'
    }

    It 'takes piped JSON through the top-level forwarder' {
        $root = New-ManifestRoot 'feedback-forwarder-pipe'
        $json = '{ "prs": [], "items": [ { "kind": "thread", "ref": "2", "ask": "Add a test.", "triage": "fix-now" } ] }'
        $json | & $script:FeedbackForwarder -Ticket WI00020 -Root $root
        (Get-Manifest $root).feedback.items[0].ask | Should -Be 'Add a test.'
    }

    It 'refuses an item with an unknown triage bucket' {
        $root = New-ManifestRoot 'feedback-bad'
        $json = '{ "prs": [], "items": [ { "kind": "thread", "ref": "1", "ask": "x", "triage": "later" } ] }'
        { & $script:Feedback -Ticket WI00020 -Json $json -Root $root } | Should -Throw '*triage*'
    }

    It 'refuses feedback without an items array' {
        $root = New-ManifestRoot 'feedback-noitems'
        { & $script:Feedback -Ticket WI00020 -Json '{ "prs": [] }' -Root $root } | Should -Throw "*'items'*"
    }
}

AfterAll {
    Get-ChildItem -LiteralPath $TestDrive -Recurse -Force -File | ForEach-Object { $_.IsReadOnly = $false }
}
