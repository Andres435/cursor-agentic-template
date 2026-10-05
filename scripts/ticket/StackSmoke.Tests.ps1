# Invoke-Pester ./scripts/ticket/StackSmoke.Tests.ps1 -Output Detailed
#Requires -Modules Pester

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $lib = Join-Path (Join-Path $PSScriptRoot 'lib') 'ManifestFields.ps1'
    . $lib

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
    New-TestRepo $script:StagedRepo -Staged
}

AfterAll {
    Get-ChildItem -LiteralPath $TestDrive -Recurse -Force -File -ErrorAction SilentlyContinue |
        ForEach-Object { $_.IsReadOnly = $false }
}

Describe 'Set-StackSmoke against a temp manifest' {
    It 'merges stackSmoke without dropping reviewReady' {
        $root = Join-Path $TestDrive 'smoke-root'
        $tmp = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $mf = Join-Path $tmp 'WI00011-manifest.json'
        '{"mode":"branch","reviewReady":{"mode":"staged"}}' | Set-Content -LiteralPath $mf -Encoding UTF8
        $script = Join-Path $PSScriptRoot 'Set-StackSmoke.ps1'
        $paths = @{ app = $script:StagedRepo } | ConvertTo-Json -Compress
        & $script -Ticket WI00011 -Status passed -Notes 'Reset form then consume-on-success.' -Preset web -RepoPaths $paths -Root $root
        $got = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
        $got.mode | Should -Be 'branch'
        $got.reviewReady.mode | Should -Be 'staged'
        $got.stackSmoke.status | Should -Be 'passed'
        $got.stackSmoke.notes | Should -Be 'Reset form then consume-on-success.'
        $got.stackSmoke.preset | Should -Be 'web'
        $got.stackSmoke.fingerprint | Should -Match '^[0-9a-f]{64}$'
        $got.stackSmoke.atUtc | Should -Not -BeNullOrEmpty
    }

    It 'stamps skipped with a reason' {
        $root = Join-Path $TestDrive 'smoke-skip'
        $tmp = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $mf = Join-Path $tmp 'WI00012-manifest.json'
        '{"mode":"branch"}' | Set-Content -LiteralPath $mf -Encoding UTF8
        & (Join-Path $PSScriptRoot 'Set-StackSmoke.ps1') -Ticket WI00012 -Status skipped -Notes 'No UI surface.' -Root $root
        $got = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
        $got.stackSmoke.status | Should -Be 'skipped'
        $got.stackSmoke.notes | Should -Be 'No UI surface.'
        $got.stackSmoke.PSObject.Properties.Name | Should -Not -Contain 'preset'
        $got.stackSmoke.PSObject.Properties.Name | Should -Not -Contain 'fingerprint'
    }

    It 'marks stale and keeps lastStatus from a prior pass' {
        $root = Join-Path $TestDrive 'smoke-stale'
        $tmp = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $mf = Join-Path $tmp 'WI00014-manifest.json'
        '{"mode":"branch"}' | Set-Content -LiteralPath $mf -Encoding UTF8
        $set = Join-Path $PSScriptRoot 'Set-StackSmoke.ps1'
        $paths = @{ app = $script:StagedRepo } | ConvertTo-Json -Compress
        & $set -Ticket WI00014 -Status passed -Notes 'First pass.' -RepoPaths $paths -Root $root
        & $set -Ticket WI00014 -Status stale -Notes 'PR comment changed link expiry.' -Root $root
        $got = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
        $got.stackSmoke.status | Should -Be 'stale'
        $got.stackSmoke.lastStatus | Should -Be 'passed'
        $got.stackSmoke.notes | Should -Be 'PR comment changed link expiry.'
        $got.stackSmoke.fingerprint | Should -Match '^[0-9a-f]{64}$'
    }

    It 'throws when the manifest is missing' {
        $root = Join-Path $TestDrive 'smoke-missing'
        New-Item -ItemType Directory -Path (Join-Path $root 'plans') -Force | Out-Null
        { & (Join-Path $PSScriptRoot 'Set-StackSmoke.ps1') -Ticket WI00013 -Status passed -Root $root } |
            Should -Throw '*Manifest not found*'
    }
}

Describe 'Get-StackSmokeDecision' {
    It 'is Never tested with no stamp' {
        $d = Get-StackSmokeDecision -Stamp $null -RepoPaths @{}
        $d.effective | Should -Be 'never'
        $d.label | Should -Be 'Never tested'
    }

    It 'is Tested when passed fingerprint still matches' {
        $fp = Get-StackSmokeWorkFingerprint -RepoPaths @{ app = $script:StagedRepo }
        $stamp = [pscustomobject]@{ status = 'passed'; fingerprint = $fp; fpVersion = 2 }
        $d = Get-StackSmokeDecision -Stamp $stamp -RepoPaths @{ app = $script:StagedRepo }
        $d.effective | Should -Be 'passed'
        $d.label | Should -Be 'Tested'
        $d.reason | Should -Be 'fingerprint-match'
    }

    It 'still reads a stamp written before fpVersion (plain git diff) as Tested' {
        $fp = Get-StackSmokeWorkFingerprint -RepoPaths @{ app = $script:StagedRepo } -Version 1
        $stamp = [pscustomobject]@{ status = 'passed'; fingerprint = $fp }
        $d = Get-StackSmokeDecision -Stamp $stamp -RepoPaths @{ app = $script:StagedRepo }
        $d.label | Should -Be 'Tested'
    }

    It 'is Untested latest changes when work moved after a pass' {
        $stamp = [pscustomobject]@{ status = 'passed'; fingerprint = 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef' }
        $d = Get-StackSmokeDecision -Stamp $stamp -RepoPaths @{ app = $script:StagedRepo }
        $d.effective | Should -Be 'stale'
        $d.label | Should -Be 'Untested latest changes'
        $d.reason | Should -Be 'fingerprint-mismatch'
        $d.lastStatus | Should -Be 'passed'
    }
}
