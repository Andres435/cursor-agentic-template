#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for ledger column migration (11-col to CtxS%/CtxR%/Ctx%).
#>

BeforeAll {
    function Get-PowerShell7Path {
        $cmd = Get-Command 'pwsh' -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { return $cmd.Source }
        throw "PowerShell 7 (pwsh) is required. See MACHINE-SETUP.md."
    }
    $script:PwshHost = Get-PowerShell7Path
    $script:LedgerScript = Join-Path $PSScriptRoot 'Update-TicketLedger.ps1'
}

Describe 'Update-TicketLedger column migration' {
    It 'keeps old Ctx% in Ctx% and inserts empty CtxS%/CtxR%' {
        $root = Join-Path $TestDrive 'ledger-root'
        $plans = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $plans -Force | Out-Null
        $old = @(
            '# Ticket ledger'
            ''
            '| Tickets | Scored | Avg E | Avg C | Avg $tok | Avg Ctx% |'
            '|---|---|---|---|---|---|'
            '| 1 | 1 | 4 | 4 | 3 | 45% |'
            ''
            '| Ticket | Type | Closed | Mode | Hours | Pts | E | C | $tok | Ctx% | PR |'
            '|---|---|---|---|---|---|---|---|---|---|---|'
            '| WI00001 | feature | 2026-09-01 | branch | 4 | 2 | 4 | 4 | 3 | 45 | 123 |'
        ) -join "`n"
        [System.IO.File]::WriteAllText((Join-Path $plans 'ticket-ledger.md'), $old + "`n", (New-Object System.Text.UTF8Encoding $false))

        & $script:PwshHost -NonInteractive -NoProfile -File $script:LedgerScript -Rewrite -Root $root
        $LASTEXITCODE | Should -Be 0

        $text = Get-Content -LiteralPath (Join-Path $plans 'ticket-ledger.md') -Raw -Encoding UTF8
        $text | Should -Match 'CtxS%'
        $text | Should -Match 'CtxR%'
        $hdr = ($text -split "`n" | Where-Object { $_ -match 'Ticket.*Type.*Closed' } | Select-Object -First 1)
        $hdr | Should -Match 'CtxS%'
        $row = ($text -split "`n" | Where-Object { $_ -match '^\|\s*WI00001' } | Select-Object -First 1)
        $cells = @(($row.Trim() -replace '^\|', '' -replace '\|$', '') -split '\|' | ForEach-Object { $_.Trim() })
        $cells.Count | Should -Be 13
        $cells[9] | Should -Be ''
        $cells[10] | Should -Be ''
        $cells[11] | Should -Be '45'
        $cells[12] | Should -Be '123'
    }
}
