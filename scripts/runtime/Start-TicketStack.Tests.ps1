#Requires -Version 7
#Requires -Modules Pester

BeforeAll {
    $script:Launcher = Join-Path $PSScriptRoot 'Start-TicketStack.ps1'
    $script:ScriptsDir = Split-Path $PSScriptRoot -Parent
    $script:RepoRoot = Split-Path $script:ScriptsDir -Parent

    # A copy of the launchers under the gitignored tmp/ (an application allowlist only lets
    # .ps1 files run inside the repos). Each copy has its own state and owner files.
    function New-StackFixture([string]$Name, $Stack) {
        $fx = Join-Path $script:RepoRoot ("tmp/stack-fixtures/start-$Name-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
        foreach ($sub in @('runtime', 'lib')) {
            New-Item -ItemType Directory -Path (Join-Path $fx "scripts/$sub") -Force | Out-Null
            Get-ChildItem (Join-Path $script:ScriptsDir $sub) -Filter '*.ps1' | Where-Object { $_.Name -notlike '*.Tests.ps1' } |
                Copy-Item -Destination (Join-Path $fx "scripts/$sub")
        }
        @{ stacks = $Stack } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $fx 'profile.json')
        return $fx
    }
    function Invoke-Start([string]$Fx, [string[]]$Arguments) {
        $out = & pwsh -NoProfile -File (Join-Path $Fx 'scripts/runtime/Start-TicketStack.ps1') @Arguments 2>&1 | Out-String
        return [pscustomobject]@{ Out = $out; Code = $LASTEXITCODE }
    }
    function Stop-FixtureProcesses([string]$Fx) {
        & pwsh -NoProfile -File (Join-Path $Fx 'scripts/runtime/Stop-TicketStack.ps1') -Force 2>&1 | Out-Null
    }
    $script:Fixtures = @()
}

AfterAll {
    foreach ($fx in $script:Fixtures) {
        if (Test-Path -LiteralPath $fx) { Remove-Item -LiteralPath $fx -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Start-TicketStack profile services' {
    It 'prints each service command under WhatIf and does not start it' {
        $dir = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Path $dir | Out-Null
        $profilePath = Join-Path $dir 'profile.json'
        @{
            stacks = @{
                default = 'all'
                services = @(
                    @{ name = 'web'; command = 'npm run dev'; cwd = '.'; port = 3999; url = 'http://localhost:3999' }
                )
            }
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $profilePath
        $output = & pwsh -NoProfile -File $script:Launcher -ProfilePath $profilePath -WhatIf 2>&1 | Out-String
        $output | Should -Match 'npm run dev'
        $output | Should -Not -Match '\[PASS\] Started 1'
    }

    It 'refuses a start command that points at this script when services is empty' {
        $dir = Join-Path $TestDrive 'empty'
        New-Item -ItemType Directory -Path $dir | Out-Null
        $profilePath = Join-Path $dir 'profile.json'
        @{
            stacks = @{
                startCommand = './scripts/runtime/Start-TicketStack.ps1'
                services = @()
            }
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $profilePath
        $output = & pwsh -NoProfile -File $script:Launcher -ProfilePath $profilePath 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 1
        $output | Should -Match 'no services'
    }

    It 'refuses an empty stack with no startCommand at all' {
        $fx = New-StackFixture 'none' @{ default = 'all'; presets = @{ all = @() }; services = @() }
        $script:Fixtures += $fx
        $r = Invoke-Start $fx @()
        $r.Code | Should -Be 1
        $r.Out | Should -Match 'no services'
    }

    It 'fails on an unknown preset' {
        $fx = New-StackFixture 'preset' @{ services = @(@{ name = 'a'; command = 'Start-Sleep 1' }) }
        $script:Fixtures += $fx
        $r = Invoke-Start $fx @('-Preset', 'nope')
        $r.Code | Should -Be 1
        $r.Out | Should -Match 'Unknown preset'
    }

    It 'fails on a dependsOn cycle and on an unknown dependsOn name' {
        $fx = New-StackFixture 'cycle' @{ services = @(
                @{ name = 'a'; command = 'Start-Sleep 1'; dependsOn = @('b') },
                @{ name = 'b'; command = 'Start-Sleep 1'; dependsOn = @('a') }) }
        $script:Fixtures += $fx
        $r = Invoke-Start $fx @()
        $r.Code | Should -Be 1
        $r.Out | Should -Match 'cycle'
        $fx2 = New-StackFixture 'unknown' @{ services = @(@{ name = 'a'; command = 'Start-Sleep 1'; dependsOn = @('ghost') }) }
        $script:Fixtures += $fx2
        $r2 = Invoke-Start $fx2 @()
        $r2.Code | Should -Be 1
        $r2.Out | Should -Match "unknown service 'ghost'"
    }

    It 'starts a preset subset with its dependencies, claims the owner, and records state' {
        $fx = New-StackFixture 'subset' @{
            presets = @{ web = @('web') }
            services = @(
                @{ name = 'db'; command = 'Start-Sleep 60' },
                @{ name = 'web'; command = 'Start-Sleep 60'; dependsOn = @('db') },
                @{ name = 'docs'; command = 'Start-Sleep 60' })
        }
        $script:Fixtures += $fx
        try {
            $r = Invoke-Start $fx @('-Ticket', 'T-1', '-Preset', 'web')
            $r.Code | Should -Be 0
            $r.Out | Should -Match 'Started 2 service'
            $state = @(Get-Content (Join-Path $fx 'scripts/runtime/.stack-services.state.json') -Raw | ConvertFrom-Json)
            $state.name -join ',' | Should -Be 'db,web'
            (Get-Content (Join-Path $fx 'scripts/.active-stack.json') -Raw | ConvertFrom-Json).Ticket | Should -Be 'T-1'
        } finally { Stop-FixtureProcesses $fx }
    }

    It 'runs a legacy startCommand as the app service, claims the owner, and warns' {
        $fx = New-StackFixture 'legacy' @{ default = 'dev'; startCommand = 'Start-Sleep 60'; services = @() }
        $script:Fixtures += $fx
        try {
            $r = Invoke-Start $fx @('-Ticket', 'T-9')
            $r.Code | Should -Be 0
            $r.Out | Should -Match 'retired'
            @(Get-Content (Join-Path $fx 'scripts/runtime/.stack-services.state.json') -Raw | ConvertFrom-Json)[0].name | Should -Be 'app'
            (Get-Content (Join-Path $fx 'scripts/.active-stack.json') -Raw | ConvertFrom-Json).Ticket | Should -Be 'T-9'
        } finally { Stop-FixtureProcesses $fx }
    }

    It 'refuses the owner claim for another ticket without -Force' {
        $fx = New-StackFixture 'owner' @{ services = @(@{ name = 'a'; command = 'Start-Sleep 60' }) }
        $script:Fixtures += $fx
        Set-Content (Join-Path $fx 'scripts/.active-stack.json') '{"Ticket":"T-1"}'
        $r = Invoke-Start $fx @('-Ticket', 'T-2')
        $r.Code | Should -Be 1
        $r.Out | Should -Match 'T-1 already owns'
    }

    It 'fails with the not-ready message when a ready probe times out' {
        $fx = New-StackFixture 'ready' @{ services = @(@{ name = 'a'; command = 'Start-Sleep 60'; port = 5997; ready = @{ port = $true; timeoutSec = 1 } }) }
        $script:Fixtures += $fx
        try {
            $r = Invoke-Start $fx @()
            $r.Code | Should -Be 1
            $r.Out | Should -Match "'a' was not ready"
        } finally { Stop-FixtureProcesses $fx }
    }
}
