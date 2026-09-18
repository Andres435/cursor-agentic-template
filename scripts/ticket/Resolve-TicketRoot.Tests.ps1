#Requires -Modules Pester
<#
.SYNOPSIS
    Pester tests for Resolve-TicketRoot mode-precedence logic and related helpers.

.DESCRIPTION
    Pester 5 syntax (GitHub Actions installs 5.x). Run with:
    Invoke-Pester ./scripts/ticket/Resolve-TicketRoot.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $libPath = Join-Path (Join-Path $PSScriptRoot '..') '_ServiceLauncherLib.ps1'
    if (-not (Test-Path $libPath)) {
        throw "Missing _ServiceLauncherLib.ps1 at $libPath - cannot run tests"
    }
    . $libPath

    $script:FixtureDir = Join-Path $PSScriptRoot 'fixtures'

    function Get-PowerShell7Path {
        $cmd = Get-Command 'pwsh' -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { return $cmd.Source }
        throw "PowerShell 7 (pwsh) is required. See MACHINE-SETUP.md."
    }
    $script:PwshHost = Get-PowerShell7Path
}

Describe 'ConvertTo-LauncherTicketId' {
    It 'returns prefix+digits from a full ticket id' {
        $result = ConvertTo-LauncherTicketId -Raw 'WI21588'
        $result | Should -Match '21588$'
    }

    It 'returns prefix+digits from bare digits' {
        $result = ConvertTo-LauncherTicketId -Raw '21588'
        $result | Should -Match '21588$'
    }

    It 'returns prefix+digits from AB# format' {
        $result = ConvertTo-LauncherTicketId -Raw 'AB#21588'
        $result | Should -Match '21588$'
    }

    It 'returns null for empty input' {
        ConvertTo-LauncherTicketId -Raw '' | Should -BeNullOrEmpty
    }

    It 'returns null for all-letters input' {
        ConvertTo-LauncherTicketId -Raw 'NOPE' | Should -BeNullOrEmpty
    }

    It 'includes a digit suffix in the result' {
        $result = ConvertTo-LauncherTicketId -Raw 'WI99999'
        $result | Should -Match '\d+$'
    }
}

Describe 'Get-TicketManifest and Get-LauncherManifestValue' {
    It 'loads fixture manifest and reads mode field' {
        $scriptRoot = Join-Path $script:FixtureDir 'dummy'
        $manifest = Get-TicketManifest -ScriptRoot $scriptRoot -Ticket 'WI00001'
        $manifest | Should -Not -BeNullOrEmpty
        Get-LauncherManifestValue -Manifest $manifest -Property 'mode' | Should -Be 'branch'
    }

    It 'returns null when manifest file does not exist' {
        $scriptRoot = Join-Path $script:FixtureDir 'dummy'
        $manifest = Get-TicketManifest -ScriptRoot $scriptRoot -Ticket 'WI99999'
        $manifest | Should -BeNullOrEmpty
    }

    It 'returns null from GetValue on a null manifest' {
        Get-LauncherManifestValue -Manifest $null -Property 'mode' | Should -BeNullOrEmpty
    }

    It 'returns null when property is absent' {
        $src = Join-Path $script:FixtureDir 'manifest-branch.json'
        $m = Get-Content $src -Raw | ConvertFrom-Json
        Get-LauncherManifestValue -Manifest $m -Property 'nonExistentField' | Should -BeNullOrEmpty
    }
}

Describe 'Mode-precedence assertions against fixture manifests' {
    It 'manifest-branch.json has mode=branch' {
        $src = Join-Path $script:FixtureDir 'manifest-branch.json'
        $m   = Get-Content $src -Raw | ConvertFrom-Json
        Get-LauncherManifestValue -Manifest $m -Property 'mode' | Should -Be 'branch'
    }

    It 'manifest-worktree.json has mode=worktree' {
        $src = Join-Path $script:FixtureDir 'manifest-worktree.json'
        $m   = Get-Content $src -Raw | ConvertFrom-Json
        Get-LauncherManifestValue -Manifest $m -Property 'mode' | Should -Be 'worktree'
    }

    It 'manifest-branch.json has startedAtUtc' {
        $src = Join-Path $script:FixtureDir 'manifest-branch.json'
        $m   = Get-Content $src -Raw | ConvertFrom-Json
        Get-LauncherManifestValue -Manifest $m -Property 'startedAtUtc' | Should -Not -BeNullOrEmpty
    }

    It 'manifest-worktree.json has startedAtUtc' {
        $src = Join-Path $script:FixtureDir 'manifest-worktree.json'
        $m   = Get-Content $src -Raw | ConvertFrom-Json
        Get-LauncherManifestValue -Manifest $m -Property 'startedAtUtc' | Should -Not -BeNullOrEmpty
    }

    It 'mode precedence: manifest branch wins even if a leftover worktree folder exists' {
        $src = Join-Path $script:FixtureDir 'manifest-branch.json'
        $m   = Get-Content $src -Raw | ConvertFrom-Json
        $manifestMode = Get-LauncherManifestValue -Manifest $m -Property 'mode'
        $resolved = Resolve-TicketMode -ManifestMode $manifestMode
        $resolved.mode | Should -Be 'branch'
        $resolved.modeSource | Should -Be 'manifest'
    }

    It 'mode precedence: leftover populated worktree does not override default branch' {
        $resolved = Resolve-TicketMode -ManifestMode $null
        $resolved.mode | Should -Be 'branch'
        $resolved.modeSource | Should -Be 'default'
    }

    It 'mode precedence: default is branch when no manifest' {
        $resolved = Resolve-TicketMode -ManifestMode ''
        $resolved.mode | Should -Be 'branch'
        $resolved.modeSource | Should -Be 'default'
    }

    It 'mode precedence: manifest worktree still wins so --worktree tickets keep working' {
        $src = Join-Path $script:FixtureDir 'manifest-worktree.json'
        $m   = Get-Content $src -Raw | ConvertFrom-Json
        $manifestMode = Get-LauncherManifestValue -Manifest $m -Property 'mode'
        $resolved = Resolve-TicketMode -ManifestMode $manifestMode
        $resolved.mode | Should -Be 'worktree'
        $resolved.modeSource | Should -Be 'manifest'
    }
}

Describe 'Assert-TicketArtifacts fixture: start phase' {
    It 'passes for a complete start-phase fixture' {
        $fixtureRoot = Join-Path $PSScriptRoot 'fixtures'
        $script = Join-Path $PSScriptRoot 'Assert-TicketArtifacts.ps1'
        $null = & $script:PwshHost -NonInteractive -NoProfile -File $script `
            -Ticket 'WI00001' -Phase 'start' -Root $fixtureRoot 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'Assert-TicketArtifacts fixture: close phase' {
    It 'passes for a complete close-phase fixture' {
        $fixtureRoot = Join-Path $PSScriptRoot 'fixtures'
        $script = Join-Path $PSScriptRoot 'Assert-TicketArtifacts.ps1'
        $null = & $script:PwshHost -NonInteractive -NoProfile -File $script `
            -Ticket 'WI00001' -Phase 'close' -Root $fixtureRoot 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
