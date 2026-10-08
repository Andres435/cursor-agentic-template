#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for Get-EnforcementUpkeep.ps1 (waiver, claim and hook-error report).
#>

BeforeAll {
    $script:Script = Join-Path $PSScriptRoot 'Get-EnforcementUpkeep.ps1'

    function New-Repo {
        $repo = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $repo 'scripts/ticket') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $repo 'scripts/ticket/doc-claims.psd1') -Value "@{ Claims = @(@{Id='a'},@{Id='b'}); CoChange = @(@{Id='gates'}) }"
        & git -C $repo init -q
        $repo
    }
    function Add-Commit([string]$Repo, [string]$Message) {
        Set-Content -LiteralPath (Join-Path $Repo ([guid]::NewGuid().ToString('N'))) -Value 'x'
        & git -C $Repo add -A
        & git -C $Repo -c user.email=t@example.com -c user.name=t commit -q -m $Message
        if ($LASTEXITCODE -ne 0) { throw 'commit failed' }
    }
}

Describe 'Get-EnforcementUpkeep' {
    It 'counts waivers per rule and flags a thin reason' {
        $repo = New-Repo
        Add-Commit $repo "one`n`nDocs-Unaffected: gates: refactor only, no behavior change"
        Add-Commit $repo "two`n`nDocs-Unaffected: gates: short"
        $out = & $script:Script -Root $repo -HookErrorsLog (Join-Path $repo 'none.log') | Out-String
        $out | Should -Match 'waivers: 2 in the last 30'
        $out | Should -Match 'gates: 2, 1 thin reason'
    }

    It 'reports the registry size' {
        $repo = New-Repo
        $out = & $script:Script -Root $repo -HookErrorsLog (Join-Path $repo 'none.log') | Out-String
        $out | Should -Match 'claims: 2 claim\(s\), 1 co-change rule\(s\)'
    }

    It 'groups recent hook errors by hook and ignores old ones' {
        $repo = New-Repo
        $log = Join-Path $repo 'hook.log'
        $now = (Get-Date).ToUniversalTime().ToString('o')
        $old = (Get-Date).AddDays(-90).ToUniversalTime().ToString('o')
        Set-Content -LiteralPath $log -Value @(
            (@{ hook = 'claude:git-guard'; message = 'x'; at = $now } | ConvertTo-Json -Compress),
            (@{ hook = 'claude:git-guard'; message = 'y'; at = $now } | ConvertTo-Json -Compress),
            (@{ hook = 'cursor:old'; message = 'z'; at = $old } | ConvertTo-Json -Compress)
        )
        $out = & $script:Script -Root $repo -HookErrorsLog $log | Out-String
        $out | Should -Match 'hook errors: 2 in the last 30'
        $out | Should -Match 'claude:git-guard: 2'
        $out | Should -Not -Match 'cursor:old'
    }

    It 'passes with no git, no log and no registry' {
        $dir = Join-Path $TestDrive 'empty'
        New-Item -ItemType Directory -Path $dir | Out-Null
        $out = & $script:Script -Root $dir -HookErrorsLog (Join-Path $dir 'none.log') | Out-String
        $out | Should -Match 'waivers: 0'
        $out | Should -Match 'doc-claims.psd1 not found'
        $out | Should -Match 'hook errors: 0'
    }
}
