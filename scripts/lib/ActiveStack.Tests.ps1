#Requires -Modules Pester
<#
.SYNOPSIS
    Pester tests for the single active-stack owner file.

.DESCRIPTION
    Pester 5 syntax. Run with:
    Invoke-Pester ./scripts/lib/ActiveStack.Tests.ps1 -Output Detailed
#>

BeforeAll {
    . (Join-Path (Split-Path $PSScriptRoot -Parent) '_ServiceLauncherLib.ps1')
    . (Join-Path $PSScriptRoot 'ActiveStack.ps1')
    $script:PriorDir = $env:TMO_ACTIVE_STACK_DIR
}

AfterAll {
    $env:TMO_ACTIVE_STACK_DIR = $script:PriorDir
}

Describe 'Active-stack owner file' {
    BeforeEach {
        $script:Dir = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Path (Join-Path $script:Dir 'runtime') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:Dir 'worktree') -Force | Out-Null
        $env:TMO_ACTIVE_STACK_DIR = $script:Dir
    }

    It 'is the same file whatever folder the caller passes' {
        $a = Get-ActiveStackFile -ScriptRoot (Join-Path $script:Dir 'runtime')
        $b = Get-ActiveStackFile -ScriptRoot (Join-Path $script:Dir 'worktree')
        $a | Should -Be $b
        $a | Should -Be (Join-Path $script:Dir '.active-stack.json')
    }

    It 'a claim from a runtime launcher is seen by a worktree script' {
        Set-ActiveStackState -ScriptRoot (Join-Path $script:Dir 'runtime') -Ticket 'WI11111'
        (Get-ActiveStackState -ScriptRoot (Join-Path $script:Dir 'worktree')).Ticket | Should -Be 'WI11111'
        Test-ActiveStackConflict -ScriptRoot (Join-Path $script:Dir 'worktree') -Ticket 'WI22222' | Should -Be 'WI11111'
    }

    It 'moves the newest legacy per-caller file into place once' {
        $old = Join-Path $script:Dir 'worktree/.active-stack.json'
        $new = Join-Path $script:Dir 'runtime/.active-stack.json'
        '{"Ticket":"WI00001"}' | Set-Content -LiteralPath $old
        (Get-Item -LiteralPath $old -Force).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddHours(-1)
        '{"Ticket":"WI00002"}' | Set-Content -LiteralPath $new
        (Get-ActiveStackState -ScriptRoot $script:Dir).Ticket | Should -Be 'WI00002'
        Test-Path -LiteralPath $new | Should -Be $false
    }
}
