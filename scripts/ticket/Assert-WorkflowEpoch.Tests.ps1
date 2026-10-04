#Requires -Modules Pester
<#
.SYNOPSIS
    Ledger row integrity, the computed epoch id, and the re-rate trigger.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot 'Assert-WorkflowEpoch.ps1')
    $script:EpochScript = Join-Path $PSScriptRoot 'Assert-WorkflowEpoch.ps1'
    $script:Utf8 = New-Object System.Text.UTF8Encoding $false

    function Write-Ledger {
        param([Parameter(Mandatory)][string]$Root, [string[]]$Rows, [string]$Rated)
        $plans = Join-Path $Root 'plans'
        New-Item -ItemType Directory -Path $plans -Force | Out-Null
        $lines = @()
        if ($Rated) { $lines += "Rated: $Rated"; $lines += '' }
        $lines += '| Ticket | Type | Closed | Mode | Hours | Pts | E | C | $tok | CtxS% | CtxR% | Ctx% | PR | Lanes | Epoch |'
        $lines += '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|'
        $lines += $Rows
        [System.IO.File]::WriteAllText((Join-Path $plans 'ticket-ledger.md'), ($lines -join "`n") + "`n", $script:Utf8)
    }

    function Get-Row([string]$Ticket, [string]$Closed, [string]$Epoch) {
        "| $Ticket | bug | $Closed | branch | 1 | 1 | 4 | 4 | 3 |  |  |  | 1 |  | $Epoch |"
    }

    # A git repo holding one watched contract file, committed.
    function New-ContractRepo([string]$Path) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $Path 'USER-MANUAL.md'), "v1`n", $script:Utf8)
        [System.IO.File]::WriteAllText((Join-Path $Path 'profile.json'), '{"epochRerateAfter":2}', $script:Utf8)
        & git -C $Path init -q
        & git -C $Path add -- USER-MANUAL.md profile.json
        & git -C $Path -c user.email=e@t -c user.name=e commit -q -m base
    }
}

AfterAll {
    # git writes object files read-only on Windows, which breaks Pester's TestDrive cleanup.
    Get-ChildItem -LiteralPath $TestDrive -Recurse -Force -File | ForEach-Object { $_.IsReadOnly = $false }
}

Describe 'Assert-WorkflowEpoch ledger rows' {
    It 'fails a blank close date' {
        $root = Join-Path $TestDrive 'blank-close'
        Write-Ledger -Root $root -Rows @(Get-Row 'WI00009' '' '')
        (Test-EpochLedgerRows -Root $root) -join "`n" | Should -Match 'WI00009 has no close date'
    }

    It 'accepts blank context percents and a blank epoch' {
        $root = Join-Path $TestDrive 'blank-ctx'
        Write-Ledger -Root $root -Rows @(Get-Row 'WI00009' '2026-09-15' '')
        $problems = Test-EpochLedgerRows -Root $root
        @($problems).Count | Should -Be 0
    }

    It 'passes when there is no local ledger (fresh clone, CI)' {
        $root = Join-Path $TestDrive 'no-ledger'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        & pwsh -NoProfile -NonInteractive -File $script:EpochScript -Root $root | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'Workflow epoch id and re-rate' {
    BeforeAll {
        $script:Repo = Join-Path $TestDrive 'contract'
        New-ContractRepo $script:Repo
        $script:Id1 = Get-WorkflowEpochId -Root $script:Repo
    }

    It 'is stable for the same tree' {
        $script:Id1 | Should -Match '^[0-9a-f]{8}$'
        Get-WorkflowEpochId -Root $script:Repo | Should -Be $script:Id1
    }

    It 'is empty outside a git checkout' {
        Get-WorkflowEpochId -Root $TestDrive | Should -Be ''
    }

    It 'is not due before the threshold' {
        Write-Ledger -Root $script:Repo -Rows @(Get-Row 'WI00001' '2026-09-01' $script:Id1)
        (Get-EpochStatus -Root $script:Repo).due | Should -Be $false
    }

    It 'is due at the threshold with no rating, and the script says re-rate without failing' {
        Write-Ledger -Root $script:Repo -Rows @(
            (Get-Row 'WI00001' '2026-09-01' $script:Id1),
            (Get-Row 'WI00002' '2026-09-02' $script:Id1))
        $s = Get-EpochStatus -Root $script:Repo
        $s.closes | Should -Be 2
        $s.due | Should -Be $true
        $out = & pwsh -NoProfile -NonInteractive -File $script:EpochScript -Root $script:Repo 2>&1
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match 're-rate'
    }

    It 'is not due once the epoch is rated' {
        Write-Ledger -Root $script:Repo -Rated $script:Id1 -Rows @(
            (Get-Row 'WI00001' '2026-09-01' $script:Id1),
            (Get-Row 'WI00002' '2026-09-02' $script:Id1))
        (Get-EpochStatus -Root $script:Repo).due | Should -Be $false
    }

    It 'a watched-file commit makes a new epoch, reported as info, never a failure' {
        [System.IO.File]::WriteAllText((Join-Path $script:Repo 'USER-MANUAL.md'), "v2`n", $script:Utf8)
        & git -C $script:Repo -c user.email=e@t -c user.name=e commit -q -am change
        $id2 = Get-WorkflowEpochId -Root $script:Repo
        $id2 | Should -Not -Be $script:Id1
        $s = Get-EpochStatus -Root $script:Repo
        $s.closes | Should -Be 0
        $s.previous | Should -Be $script:Id1
        $out = & pwsh -NoProfile -NonInteractive -File $script:EpochScript -Root $script:Repo 2>&1
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match 'new workflow epoch'
    }
}
