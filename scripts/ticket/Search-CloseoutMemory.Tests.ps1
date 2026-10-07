#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for Search-CloseoutMemory.ps1: the closeout index's Status column.
    Run: Invoke-Pester ./scripts/ticket/Search-CloseoutMemory.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $script:Search = Join-Path $PSScriptRoot 'Search-CloseoutMemory.ps1'
    . (Join-Path $PSScriptRoot 'lib/TicketPrefix.ps1')
    $script:Prefix = Get-TicketPrefix
}

Describe 'Search-CloseoutMemory' {
    It 'returns active rows, skips superseded ones, and still reads three-column rows' {
        $p = $script:Prefix
        $index = Join-Path $TestDrive 'closeout-index.md'
        Set-Content -LiteralPath $index -Encoding UTF8 -Value @(
            '| Ticket | Domain | Lesson | Status | Added |'
            '|---|---|---|---|---|'
            "| ${p}10001 | release | Release PRs target main. | active | 2026-10-07 |"
            "| ${p}10002 | release | Release PRs target ${p}12288. | superseded: they target main | 2026-08-16 |"
            "| ${p}10003 | release | Older release row with no status column. |"
        )
        $hits = & $script:Search -Query 'release PRs' -IndexPath $index | ConvertFrom-Json
        @($hits.ticket) | Should -Contain "${p}10001"
        @($hits.ticket) | Should -Contain "${p}10003"
        @($hits.ticket) | Should -Not -Contain "${p}10002"
    }

    It 'gives the real index a Status and Added column, and every row an Added date' {
        $real = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'plans/closeout-index.md'
        $lines = @(Get-Content -LiteralPath $real -Encoding UTF8)
        $lines | Should -Contain '| Ticket | Domain | Lesson | Status | Added |'
        $rowPattern = '^\|\s*(' + [regex]::Escape($script:Prefix) + '\d+|—)\s*\|'
        foreach ($row in @($lines | Where-Object { $_ -match $rowPattern })) {
            $cols = @($row.Trim().Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
            $cols.Count | Should -Be 5 -Because "every row has Ticket | Domain | Lesson | Status | Added: $($cols[0])"
            $cols[4] | Should -Match '^\d{4}-\d{2}-\d{2}$' -Because "Added is a date: $($cols[0])"
        }
    }
}
