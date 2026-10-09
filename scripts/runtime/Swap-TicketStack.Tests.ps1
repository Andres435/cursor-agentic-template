#Requires -Version 7
#Requires -Modules Pester

BeforeAll {
    $script:ScriptsDir = Split-Path $PSScriptRoot -Parent
    $script:RepoRoot = Split-Path $script:ScriptsDir -Parent

    # The real Swap script beside stubs that log their call, so the order is observable.
    function New-SwapFixture([int]$StopExit = 0) {
        $fx = Join-Path $script:RepoRoot ("tmp/stack-fixtures/swap-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
        $rt = Join-Path $fx 'scripts/runtime'
        New-Item -ItemType Directory -Path $rt -Force | Out-Null
        Copy-Item (Join-Path $PSScriptRoot 'Swap-TicketStack.ps1') $rt
        $log = Join-Path $fx 'calls.log'
        Set-Content (Join-Path $rt 'Stop-TicketStack.ps1') "Add-Content '$log' ('stop ' + (`$args -join ' ')); exit $StopExit"
        Set-Content (Join-Path $rt 'Set-ActiveStack.ps1') "Add-Content '$log' ('claim ' + (`$args -join ' '))"
        Set-Content (Join-Path $rt 'Start-TicketStack.ps1') "Add-Content '$log' ('start ' + (`$args -join ' '))"
        return $fx
    }
    $script:Fixtures = @()
}

AfterAll {
    foreach ($fx in $script:Fixtures) {
        if (Test-Path -LiteralPath $fx) { Remove-Item -LiteralPath $fx -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Swap-TicketStack' {
    It 'stops (forced), claims the target, then starts with the same preset' {
        $fx = New-SwapFixture
        $script:Fixtures += $fx
        & pwsh -NoProfile -File (Join-Path $fx 'scripts/runtime/Swap-TicketStack.ps1') -Ticket T-2 -Preset web -Setup
        $LASTEXITCODE | Should -Be 0
        $calls = @(Get-Content (Join-Path $fx 'calls.log'))
        $calls.Count | Should -Be 3
        $calls[0] | Should -Be 'stop -Force'
        $calls[1] | Should -Be 'claim -Ticket T-2 -Force'
        $calls[2] | Should -Be 'start -Ticket T-2 -Preset web -Setup'
    }

    It 'does not claim or start when the stop fails' {
        $fx = New-SwapFixture -StopExit 4
        $script:Fixtures += $fx
        & pwsh -NoProfile -File (Join-Path $fx 'scripts/runtime/Swap-TicketStack.ps1') -Ticket T-2 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 4
        @(Get-Content (Join-Path $fx 'calls.log')).Count | Should -Be 1
    }

    It 'runs nothing under WhatIf' {
        $fx = New-SwapFixture
        $script:Fixtures += $fx
        & pwsh -NoProfile -File (Join-Path $fx 'scripts/runtime/Swap-TicketStack.ps1') -Ticket T-2 -WhatIf 2>&1 | Out-Null
        Test-Path (Join-Path $fx 'calls.log') | Should -BeFalse
    }
}
