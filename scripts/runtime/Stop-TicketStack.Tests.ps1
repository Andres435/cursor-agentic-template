#Requires -Version 7
#Requires -Modules Pester

BeforeAll {
    $script:ScriptsDir = Split-Path $PSScriptRoot -Parent
    $script:RepoRoot = Split-Path $script:ScriptsDir -Parent

    function New-StopFixture {
        $fx = Join-Path $script:RepoRoot ("tmp/stack-fixtures/stop-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
        foreach ($sub in @('runtime', 'lib')) {
            New-Item -ItemType Directory -Path (Join-Path $fx "scripts/$sub") -Force | Out-Null
            Get-ChildItem (Join-Path $script:ScriptsDir $sub) -Filter '*.ps1' | Where-Object { $_.Name -notlike '*.Tests.ps1' } |
                Copy-Item -Destination (Join-Path $fx "scripts/$sub")
        }
        return $fx
    }
    function Invoke-Stop([string]$Fx, [string[]]$Arguments) {
        $out = & pwsh -NoProfile -File (Join-Path $Fx 'scripts/runtime/Stop-TicketStack.ps1') @Arguments 2>&1 | Out-String
        return [pscustomobject]@{ Out = $out; Code = $LASTEXITCODE }
    }
    $script:Fixtures = @()
}

AfterAll {
    foreach ($fx in $script:Fixtures) {
        if (Test-Path -LiteralPath $fx) { Remove-Item -LiteralPath $fx -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Stop-TicketStack' {
    It 'kills the whole process tree, runs stop in reverse order, removes state and clears the owner' {
        $fx = New-StopFixture
        $script:Fixtures += $fx
        $marker = Join-Path $fx 'stopped.txt'
        # A wrapper pwsh that spawns a grandchild pwsh: the shape of `npm run dev` or `dotnet run`.
        $wrapper = Start-Process pwsh -PassThru -ArgumentList @('-NoProfile', '-Command',
            "Start-Process pwsh -ArgumentList '-NoProfile','-Command','Start-Sleep 120'; Start-Sleep 120")
        $child = $null
        foreach ($i in 1..40) {
            $child = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($wrapper.Id)" | Select-Object -First 1
            if ($child) { break }
            Start-Sleep -Milliseconds 250
        }
        $child | Should -Not -BeNullOrEmpty
        $second = Start-Process pwsh -PassThru -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep 120')
        # Reverse order: second runs its stop first (Set-Content), then first (Add-Content).
        $state = @(
            [pscustomobject]@{ name = 'first'; processId = $wrapper.Id; cwd = $fx; stop = 'Add-Content stopped.txt first' },
            [pscustomobject]@{ name = 'second'; processId = $second.Id; cwd = $fx; stop = 'Set-Content stopped.txt second' })
        ConvertTo-Json -InputObject $state | Set-Content (Join-Path $fx 'scripts/runtime/.stack-services.state.json')
        Set-Content (Join-Path $fx 'scripts/.active-stack.json') '{"Ticket":"T-1"}'
        try {
            $r = Invoke-Stop $fx @('-Ticket', 'T-1')
            $r.Code | Should -Be 0
            Get-Process -Id $wrapper.Id -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            Get-Process -Id $child.ProcessId -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            Get-Process -Id $second.Id -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            (Get-Content $marker) -join ',' | Should -Be 'second,first'
            Test-Path (Join-Path $fx 'scripts/runtime/.stack-services.state.json') | Should -BeFalse
            Test-Path (Join-Path $fx 'scripts/.active-stack.json') | Should -BeFalse
        } finally {
            foreach ($p in @($wrapper.Id, $child.ProcessId, $second.Id)) { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'refuses to stop another ticket stack without -Force, and proceeds with it' {
        $fx = New-StopFixture
        $script:Fixtures += $fx
        Set-Content (Join-Path $fx 'scripts/.active-stack.json') '{"Ticket":"T-1"}'
        $r = Invoke-Stop $fx @('-Ticket', 'T-2')
        $r.Code | Should -Be 1
        $r.Out | Should -Match 'T-1 owns'
        Test-Path (Join-Path $fx 'scripts/.active-stack.json') | Should -BeTrue
        $r2 = Invoke-Stop $fx @('-Ticket', 'T-2', '-Force')
        $r2.Code | Should -Be 0
        Test-Path (Join-Path $fx 'scripts/.active-stack.json') | Should -BeFalse
    }

    It 'reports nothing recorded and still exits 0' {
        $fx = New-StopFixture
        $script:Fixtures += $fx
        $r = Invoke-Stop $fx @()
        $r.Code | Should -Be 0
        $r.Out | Should -Match 'No recorded services'
    }
}
