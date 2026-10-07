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
        $cells.Count | Should -Be 15
        $cells[9] | Should -Be ''
        $cells[10] | Should -Be ''
        $cells[11] | Should -Be '45'
        $cells[12] | Should -Be '123'
        $cells[13] | Should -Be ''
    }

    It 'writes Lanes and a CtxS coverage line without backfilling older rows' {
        $root = Join-Path $TestDrive 'lanes-root'
        $plans = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $plans -Force | Out-Null
        & $script:PwshHost -NonInteractive -NoProfile -File $script:LedgerScript `
            -Root $root -Ticket WI00002 -Type bug -Mode branch -Efficiency 4 -Contextualization 4 -CostTokens 3 `
            -ContextPct 40 -ContextPctStart 55 -Lanes 'f1/s0/d0 inline:d2'
        $LASTEXITCODE | Should -Be 0
        $text = Get-Content -LiteralPath (Join-Path $plans 'ticket-ledger.md') -Raw -Encoding UTF8
        $text | Should -Match 'f1/s0/d0 inline:d2'
        $text | Should -Match 'CtxS on 1 of 1 scored branch rows'
    }

    It 'refuses a free-text Lanes value and writes no row' {
        $root = Join-Path $TestDrive 'lanes-free-text'
        $plans = Join-Path $root 'plans'
        New-Item -ItemType Directory -Path $plans -Force | Out-Null
        $out = & $script:PwshHost -NonInteractive -NoProfile -File $script:LedgerScript `
            -Root $root -Ticket TICKET-00003 -Type spike -Mode investigate -Efficiency 3 -Contextualization 3 -CostTokens 4 `
            -Lanes 'opus x3 verify (deep)' 2>&1 | Out-String
        $LASTEXITCODE | Should -Not -Be 0
        $out | Should -Match 'is not fN/sN/dN'
        Test-Path -LiteralPath (Join-Path $plans 'ticket-ledger.md') | Should -BeFalse
    }
}
