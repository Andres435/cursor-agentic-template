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

    It 'denies a tracked NuGet.Config once a ClearTextPassword is added to it' {
        $repo = Join-Path $TestDrive 'nuget'
        New-TicketRepo $repo
        $cfg = Join-Path $repo 'NuGet.Config'
        Set-Content -LiteralPath $cfg -Value '<configuration><packageSources /></configuration>'
        & git -C $repo add NuGet.Config
        & git -C $repo commit -q -m cfg
        Set-Content -LiteralPath $cfg -Value @(
            '<configuration><packageSources />'
            '<packageSourceCredentials><Team_x0020_Feed>'
            '<add key="ClearTextPassword" value="not-a-real-token" />'
            '</Team_x0020_Feed></packageSourceCredentials></configuration>'
        )
        $got = (& $script:SelectScript -RepoPath $repo -Json) | ConvertFrom-Json
        @($got.candidates) | Should -Not -Contain 'NuGet.Config'
        ($got.denied | Where-Object { $_.path -eq 'NuGet.Config' }).reason | Should -Be 'secret-shaped content'
    }

    It 'denies an untracked file holding a password value or a PAT-shaped token' {
        $repo = Join-Path $TestDrive 'untracked-secret'
        New-TicketRepo $repo
        Set-Content -LiteralPath (Join-Path $repo 'src/app.config') -Value 'Server=x;User Id=sa;Password=Hunter22;'
        Set-Content -LiteralPath (Join-Path $repo 'src/token.txt') -Value ('a' * 26 + '2' * 26)
        $got = (& $script:SelectScript -RepoPath $repo -Json) | ConvertFrom-Json
        @($got.candidates) | Should -Not -Contain 'src/app.config'
        @($got.candidates) | Should -Not -Contain 'src/token.txt'
        @($got.denied | Where-Object { $_.reason -eq 'secret-shaped content' }).Count | Should -Be 2
    }

    It 'keeps a file whose secret-looking line was already committed and is not part of this change' {
        $repo = Join-Path $TestDrive 'old-placeholder'
        New-TicketRepo $repo
        $cfg = Join-Path $repo 'src/app.config'
        Set-Content -LiteralPath $cfg -Value @('Password=Placeholder1', 'Timeout=30')
        & git -C $repo add src/app.config
        & git -C $repo commit -q -m cfg
        Set-Content -LiteralPath $cfg -Value @('Password=Placeholder1', 'Timeout=60')
        $got = (& $script:SelectScript -RepoPath $repo -Json) | ConvertFrom-Json
        @($got.candidates) | Should -Contain 'src/app.config'
        @($got.denied).Count | Should -Be 0
    }

    It 'does not flag an empty or templated password' {
        $repo = Join-Path $TestDrive 'templated'
        New-TicketRepo $repo
        Set-Content -LiteralPath (Join-Path $repo 'src/a.config') -Value @('Password=;', 'Password={0}', 'Password=$(DbPassword)')
        $got = (& $script:SelectScript -RepoPath $repo -Json) | ConvertFrom-Json
        @($got.candidates) | Should -Contain 'src/a.config'
    }
}
