#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for lib/TicketPrefix.ps1: one prefix source for every ticket script.
    Run: Invoke-Pester ./scripts/ticket/TicketPrefix.Tests.ps1 -Output Detailed
#>

BeforeAll {
    . (Join-Path $PSScriptRoot 'lib/ManifestFields.ps1')
}

Describe 'Get-TicketPrefix' {
    It 'reads ticketPrefix from the given root, and defaults to TICKET-' {
        $custom = Join-Path $TestDrive 'custom'
        New-Item -ItemType Directory -Path $custom -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $custom 'profile.json') -Value '{ "ticketPrefix": "TKT-" }'
        Get-TicketPrefix -Root $custom | Should -Be 'TKT-'

        $none = Join-Path $TestDrive 'none'
        New-Item -ItemType Directory -Path $none -Force | Out-Null
        Get-TicketPrefix -Root $none | Should -Be 'TICKET-'

        Set-Content -LiteralPath (Join-Path $none 'profile.json') -Value '{ not json'
        Get-TicketPrefix -Root $none | Should -Be 'TICKET-'
    }

    It 'gives bare digits this repo''s prefix and keeps an explicit one' {
        Get-TicketKeyFromRaw -Ticket '23845' | Should -Be ((Get-TicketPrefix) + '23845')
        Get-TicketKeyFromRaw -Ticket 'AB-23845' | Should -Be 'AB-23845'
        Get-TicketKeyFromRaw -Ticket 'TKT-77' | Should -Be 'TKT-77'
    }
}
