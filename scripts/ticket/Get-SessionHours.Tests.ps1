#Requires -Version 7
#Requires -Modules Pester

BeforeAll {
    $script:Script = Join-Path $PSScriptRoot 'Get-SessionHours.ps1'
}

Describe 'Get-SessionHours' {
    It 'counts only the overlap of an overnight span, not a full day on each side' {
        $root = Join-Path $TestDrive 'overnight'
        New-Item -ItemType Directory -Path (Join-Path $root 'plans') -Force | Out-Null
        $manifest = @{
            workType       = 'bug'
            mode           = 'branch'
            timezone       = 'UTC'
            startedAtUtc   = '2026-10-05T22:00:00Z'
            completedAtUtc = '2026-10-06T02:00:00Z'
        }
        $path = Join-Path $root 'plans\TICKET-44-manifest.json'
        $manifest | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding utf8
        $raw = & $script:Script -Ticket TICKET-44 -Root $root -Json
        $out = $raw | ConvertFrom-Json
        $out.hours | Should -Be 4
        $out.points | Should -Be 2
    }

    It 'includes a closed pr-feedback span after the original close' {
        $root = Join-Path $TestDrive 'feedback'
        New-Item -ItemType Directory -Path (Join-Path $root 'plans') -Force | Out-Null
        $manifest = @{
            workType       = 'bug'
            mode           = 'branch'
            timezone       = 'UTC'
            startedAtUtc   = '2026-10-05T22:00:00Z'
            completedAtUtc = '2026-10-06T02:00:00Z'
            spans          = @(
                @{
                    kind         = 'pr-feedback'
                    startedAtUtc = '2026-10-07T15:00:00Z'
                    endedAtUtc   = '2026-10-07T17:00:00Z'
                }
            )
        }
        $path = Join-Path $root 'plans\TICKET-44-manifest.json'
        $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding utf8
        $raw = & $script:Script -Ticket TICKET-44 -Root $root -Json
        $out = $raw | ConvertFrom-Json
        $out.hours | Should -Be 6
        $out.points | Should -Be 3
    }
}
