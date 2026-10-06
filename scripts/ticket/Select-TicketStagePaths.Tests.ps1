# Invoke-Pester ./scripts/ticket/Select-TicketStagePaths.Tests.ps1 -Output Detailed
#Requires -Modules Pester

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:SelectScript = Join-Path $PSScriptRoot 'Select-TicketStagePaths.ps1'

    function New-TicketRepo([string]$Path) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        & git -C $Path init -q
        & git -C $Path config user.email 't@example.com'
        & git -C $Path config user.name 't'
        $src = Join-Path $Path 'src'
        New-Item -ItemType Directory -Path $src -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $src 'App.cs') -Value 'one'
        & git -C $Path add src/App.cs
        & git -C $Path commit -q -m init
    }
}

AfterAll {
    Get-ChildItem -LiteralPath $TestDrive -Recurse -Force -File -ErrorAction SilentlyContinue |
        ForEach-Object { $_.IsReadOnly = $false }
}

Describe 'Select-TicketStagePaths' {
    It 'keeps source files and denies secret-shaped names' {
        $repo = Join-Path $TestDrive 'repo'
        New-TicketRepo $repo
        Set-Content -LiteralPath (Join-Path $repo 'src/App.cs') -Value 'two'
        Set-Content -LiteralPath (Join-Path $repo 'src/NewFile.cs') -Value 'new'
        Set-Content -LiteralPath (Join-Path $repo '.env') -Value 'secret'
        Set-Content -LiteralPath (Join-Path $repo 'credentials.json') -Value '{}'
        Set-Content -LiteralPath (Join-Path $repo 'cert.pfx') -Value 'x'
        Set-Content -LiteralPath (Join-Path $repo 'app.user') -Value 'x'

        $raw = & $script:SelectScript -RepoPath $repo -Json
        $raw | Should -Not -BeNullOrEmpty
        $got = $raw | ConvertFrom-Json
        $candidates = @($got.candidates)
        $denied = @($got.denied)

        $candidates | Should -Contain 'src/App.cs'
        $candidates | Should -Contain 'src/NewFile.cs'
        $candidates | Should -Not -Contain '.env'
        $candidates | Should -Not -Contain 'credentials.json'
        $candidates | Should -Not -Contain 'cert.pfx'
        $candidates | Should -Not -Contain 'app.user'

        @($denied | ForEach-Object { $_.path }) | Should -Contain '.env'
        ($denied | Where-Object { $_.path -eq '.env' }).reason | Should -Be 'secret-shaped name'
    }

    It 'includes a staged source file' {
        $repo = Join-Path $TestDrive 'staged'
        New-TicketRepo $repo
        Set-Content -LiteralPath (Join-Path $repo 'src/App.cs') -Value 'staged'
        & git -C $repo add src/App.cs
        $got = (& $script:SelectScript -RepoPath $repo -Json) | ConvertFrom-Json
        @($got.candidates) | Should -Contain 'src/App.cs'
        @($got.denied).Count | Should -Be 0
    }

    It 'fails when the path is not a git tree' {
        $dir = Join-Path $TestDrive 'not-git'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        { & $script:SelectScript -RepoPath $dir -Json -ErrorAction Stop } | Should -Throw
    }
}
