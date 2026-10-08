#Requires -Version 7
#Requires -Modules Pester

BeforeAll {
    $script:Launcher = Join-Path $PSScriptRoot 'Start-TicketStack.ps1'
}

Describe 'Start-TicketStack profile services' {
    It 'prints each service command under WhatIf and does not start it' {
        $dir = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Path $dir | Out-Null
        $profilePath = Join-Path $dir 'profile.json'
        @{
            stacks = @{
                default = 'dev'
                startCommand = './scripts/runtime/Start-TicketStack.ps1'
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
}
