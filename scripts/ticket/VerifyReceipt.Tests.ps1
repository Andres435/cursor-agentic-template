#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for Set-VerifyReceipt.ps1 (plans/<ticket>-verify.json).
#>

BeforeAll {
    $script:Script = Join-Path $PSScriptRoot 'Set-VerifyReceipt.ps1'
    function New-ReceiptRoot([string]$Name) {
        $root = Join-Path $TestDrive $Name
        New-Item -ItemType Directory -Path (Join-Path $root 'plans') -Force | Out-Null
        return $root
    }
    function Get-Receipt([string]$Root) {
        return @(Get-Content -LiteralPath (Join-Path $Root 'plans/WI00020-verify.json') -Raw | ConvertFrom-Json)
    }
}

Describe 'Set-VerifyReceipt' {
    It 'writes one packet per repo and replaces a repo on a second call' {
        $root = New-ReceiptRoot 'upsert'
        & $script:Script -Ticket WI00020 -Repo app -Tests fail -Sonar ok -Failing 'SomeTest' -Root $root
        & $script:Script -Ticket WI00020 -Repo api -Tests pass -Sonar ok -Root $root
        & $script:Script -Ticket WI00020 -Repo app -Tests pass -Sonar ok -Root $root
        $got = Get-Receipt $root
        $got.Count | Should -Be 2
        ($got | Where-Object repo -eq 'app').pass | Should -BeTrue
        ($got | Where-Object repo -eq 'api').pass | Should -BeTrue
    }

    It 'records pass false for failing tests, a failing name, or a Sonar error' -ForEach @(
        @{ tests = 'fail'; sonar = 'ok'; failing = @() }
        @{ tests = 'pass'; sonar = 'error'; failing = @() }
        @{ tests = 'pass'; sonar = 'ok'; failing = @('Flaky') }
    ) {
        $root = New-ReceiptRoot "fail-$tests-$sonar-$($failing.Count)"
        & $script:Script -Ticket WI00020 -Repo app -Tests $tests -Sonar $sonar -Failing $failing -Root $root
        $packet = (Get-Receipt $root)[0]
        $packet.pass | Should -BeFalse
        $packet.pass | Should -BeOfType [bool]
    }

    It 'refuses not-run tests without a reason' {
        $root = New-ReceiptRoot 'not-run'
        { & $script:Script -Ticket WI00020 -Repo app -Tests not-run -Sonar not-run -Root $root } |
            Should -Throw '*-Reason*'
    }

    It 'passes not-run tests with a reason' {
        $root = New-ReceiptRoot 'not-run-reason'
        & $script:Script -Ticket WI00020 -Repo app -Tests not-run -Sonar not-run -Reason 'docs-only' -Root $root
        $packet = (Get-Receipt $root)[0]
        $packet.pass | Should -BeTrue
        $packet.reason | Should -Be 'docs-only'
    }
}
