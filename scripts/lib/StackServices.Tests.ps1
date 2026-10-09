#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for scripts/lib/StackServices.ps1 (preset, order, env, ready, tree, start/stop, profile checks).
#>

BeforeAll {
    . (Join-Path $PSScriptRoot 'StackServices.ps1')

    function New-Svc([string]$Name, [string[]]$DependsOn, $Extra) {
        $o = [ordered]@{ name = $Name; command = "run $Name" }
        if ($DependsOn) { $o.dependsOn = $DependsOn }
        if ($Extra) { foreach ($k in $Extra.Keys) { $o[$k] = $Extra[$k] } }
        return [pscustomobject]$o
    }
    function ConvertTo-Stack([hashtable]$Table) { return ($Table | ConvertTo-Json -Depth 8 | ConvertFrom-Json) }
}

Describe 'Get-StackServiceList' {
    It 'returns the services as written' {
        $stack = ConvertTo-Stack @{ services = @(@{ name = 'a'; command = 'x' }) }
        $r = Get-StackServiceList -Stack $stack
        $r.Legacy | Should -BeFalse
        $r.Services.Count | Should -Be 1
    }
    It 'turns a legacy startCommand into one implicit app service with a warning' {
        $stack = ConvertTo-Stack @{ startCommand = 'npm run dev'; services = @() }
        $r = Get-StackServiceList -Stack $stack
        $r.Legacy | Should -BeTrue
        $r.Services[0].name | Should -Be 'app'
        $r.Services[0].command | Should -Be 'npm run dev'
        $r.Warning | Should -Match 'retired'
    }
    It 'ignores off and a command that points at the launcher itself' {
        (Get-StackServiceList -Stack (ConvertTo-Stack @{ startCommand = 'off' })).Services.Count | Should -Be 0
        (Get-StackServiceList -Stack (ConvertTo-Stack @{ startCommand = './scripts/runtime/Start-TicketStack.ps1' })).Services.Count | Should -Be 0
    }
}

Describe 'Resolve-StackSelection' {
    BeforeAll {
        $script:Services = @((New-Svc 'db'), (New-Svc 'api' @('db')), (New-Svc 'web' @('api')), (New-Svc 'docs'))
        $script:Stack = ConvertTo-Stack @{ default = 'all'; presets = @{ all = @(); web = @('web'); docs = @('docs') } }
    }
    It 'starts every service for the default empty preset, in list order' {
        (Resolve-StackSelection -Stack $script:Stack -Services $script:Services).name -join ',' | Should -Be 'db,api,web,docs'
    }
    It 'picks a preset subset and pulls in its dependencies in dependsOn order' {
        (Resolve-StackSelection -Stack $script:Stack -Services $script:Services -Preset 'web').name -join ',' | Should -Be 'db,api,web'
        (Resolve-StackSelection -Stack $script:Stack -Services $script:Services -Preset 'docs').name -join ',' | Should -Be 'docs'
    }
    It 'orders by dependsOn even when the list is out of order' {
        $svc = @((New-Svc 'web' @('api')), (New-Svc 'api'))
        (Resolve-StackSelection -Stack (ConvertTo-Stack @{}) -Services $svc).name -join ',' | Should -Be 'api,web'
    }
    It 'fails on a cycle' {
        $svc = @((New-Svc 'a' @('b')), (New-Svc 'b' @('a')))
        { Resolve-StackSelection -Stack (ConvertTo-Stack @{}) -Services $svc } | Should -Throw '*cycle*'
    }
    It 'fails on an unknown dependsOn name' {
        { Resolve-StackSelection -Stack (ConvertTo-Stack @{}) -Services @((New-Svc 'a' @('ghost'))) } | Should -Throw "*unknown service 'ghost'*"
    }
    It 'fails on an unknown preset and on a preset naming an unknown service' {
        { Resolve-StackSelection -Stack $script:Stack -Services $script:Services -Preset 'nope' } | Should -Throw '*Unknown preset*'
        $bad = ConvertTo-Stack @{ presets = @{ p = @('ghost') } }
        { Resolve-StackSelection -Stack $bad -Services $script:Services -Preset 'p' } | Should -Throw "*unknown service 'ghost'*"
    }
}

Describe 'Resolve-StackEnv' {
    It 'resolves ${env:NAME} from the environment and keeps literals' {
        $env:STACK_TEST_VALUE = 'from-env'
        try {
            $r = Resolve-StackEnv ([pscustomobject]@{ A = '${env:STACK_TEST_VALUE}'; B = 'literal'; C = 'x-${env:STACK_TEST_VALUE}-y' })
            $r.A | Should -Be 'from-env'
            $r.B | Should -Be 'literal'
            $r.C | Should -Be 'x-from-env-y'
        } finally { Remove-Item Env:STACK_TEST_VALUE -ErrorAction SilentlyContinue }
    }
    It 'fails clearly when the variable is not set' {
        { Resolve-StackEnv ([pscustomobject]@{ A = '${env:STACK_TEST_MISSING_VAR}' }) } | Should -Throw '*STACK_TEST_MISSING_VAR*not set*'
    }
}

Describe 'Wait-StackReady' {
    It 'returns at once with no ready block' {
        { Wait-StackReady -Name 'a' -Ready $null -Port 1 } | Should -Not -Throw
    }
    It 'returns when the port opens' {
        Mock Test-StackPortOpen { $true }
        { Wait-StackReady -Name 'a' -Ready ([pscustomobject]@{ port = $true }) -Port 5099 -PollMs 10 } | Should -Not -Throw
        Should -Invoke Test-StackPortOpen -Times 1
    }
    It 'probes the url when ready.url is set' {
        Mock Test-StackUrlUp { $true }
        Wait-StackReady -Name 'a' -Ready ([pscustomobject]@{ url = 'http://localhost:1/health' }) -PollMs 10
        Should -Invoke Test-StackUrlUp -Times 1 -ParameterFilter { $Url -eq 'http://localhost:1/health' }
    }
    It 'throws after timeoutSec when never ready' {
        Mock Test-StackPortOpen { $false }
        { Wait-StackReady -Name 'slow' -Ready ([pscustomobject]@{ port = $true; timeoutSec = 1 }) -Port 5099 -PollMs 50 } | Should -Throw "*'slow' was not ready*"
    }
}

Describe 'Get-StackDescendantIds' {
    It 'lists children before their parent, root last' {
        $table = @(
            [pscustomobject]@{ Id = 1; Parent = 0 }, [pscustomobject]@{ Id = 2; Parent = 1 },
            [pscustomobject]@{ Id = 3; Parent = 2 }, [pscustomobject]@{ Id = 4; Parent = 1 },
            [pscustomobject]@{ Id = 9; Parent = 8 })
        (Get-StackDescendantIds -RootId 1 -Table $table) -join ',' | Should -Be '3,2,4,1'
    }
    It 'stop-processes each id, children first' {
        Mock Get-StackProcessTable { @([pscustomobject]@{ Id = 10; Parent = 1 }, [pscustomobject]@{ Id = 11; Parent = 10 }) }
        $script:killed = @()
        Mock Stop-Process { $script:killed += $Id }
        [void](Stop-StackProcessTree -ProcessId 10)
        $script:killed -join ',' | Should -Be '11,10'
    }
}

Describe 'Start-StackServices' {
    BeforeEach {
        $script:log = New-Object System.Collections.Generic.List[string]
        Mock Test-StackPortListening { $false }
        Mock Write-Host {}
        Mock Start-StackProcess { $script:log.Add("start $Command"); [pscustomobject]@{ Id = 4242 } }
        Mock Invoke-StackCommand { $script:log.Add("cmd $Command"); 0 }
        Mock Wait-StackReady { $script:log.Add("ready $Name") }
        $script:root = $TestDrive
    }
    It 'starts in order, waits for ready between services, and records state' {
        $svc = @((New-Svc 'api' $null @{ port = 5099; ready = [pscustomobject]@{ port = $true } }), (New-Svc 'web'))
        $state = Join-Path $TestDrive 'a.state.json'
        $r = @(Start-StackServices -Services $svc -RepoRoot $script:root -StatePath $state)
        $script:log -join '|' | Should -Be 'start run api|ready api|start run web|ready web'
        $r.Count | Should -Be 2
        (Get-Content $state -Raw | ConvertFrom-Json).Count | Should -Be 2
    }
    It 'runs setup only with -Setup, before the start, and fails on a non-zero exit' {
        $svc = @((New-Svc 'api' $null @{ setup = 'restore it'; stop = 'down it' }))
        [void](Start-StackServices -Services $svc -RepoRoot $script:root)
        $script:log -join '|' | Should -Not -Match 'restore'
        $script:log.Clear()
        [void](Start-StackServices -Services $svc -RepoRoot $script:root -Setup)
        $script:log[0] | Should -Be 'cmd restore it'
        $script:log[1] | Should -Be 'start run api'
        Mock Invoke-StackCommand { 3 }
        { Start-StackServices -Services $svc -RepoRoot $script:root -Setup } | Should -Throw '*Setup for api exited 3*'
    }
    It 'skips a service whose port is already listening' {
        Mock Test-StackPortListening { $true }
        $r = @(Start-StackServices -Services @((New-Svc 'api' $null @{ port = 5099 })) -RepoRoot $script:root)
        $r.Count | Should -Be 0
        $script:log.Count | Should -Be 0
    }
    It 'records the stop command and cwd in state' {
        $state = Join-Path $TestDrive 'b.state.json'
        [void](Start-StackServices -Services @((New-Svc 'db' $null @{ stop = 'docker compose down' })) -RepoRoot $script:root -StatePath $state)
        $e = @(Get-Content $state -Raw | ConvertFrom-Json)[0]
        $e.stop | Should -Be 'docker compose down'
        $e.processId | Should -Be 4242
        $e.cwd | Should -Not -BeNullOrEmpty
    }
    It 'fails on a missing cwd' {
        { Start-StackServices -Services @((New-Svc 'a' $null @{ cwd = 'nope' })) -RepoRoot $script:root } | Should -Throw '*Working directory not found*'
    }
    It 'stops starting when a service is not ready, leaving earlier state recorded' {
        Mock Wait-StackReady { if ($Name -eq 'api') { throw "Service 'api' was not ready" } }
        $state = Join-Path $TestDrive 'c.state.json'
        { Start-StackServices -Services @((New-Svc 'api'), (New-Svc 'web')) -RepoRoot $script:root -StatePath $state } | Should -Throw '*not ready*'
        @(Get-Content $state -Raw | ConvertFrom-Json).Count | Should -Be 1
    }
}

Describe 'Start-StackProcess env' {
    It 'applies env to the child spawn and restores it afterward' {
        $script:seen = $null
        Mock Start-Process { $script:seen = $env:STACK_TEST_CHILD; [pscustomobject]@{ Id = 7 } }
        Remove-Item Env:STACK_TEST_CHILD -ErrorAction SilentlyContinue
        $p = Start-StackProcess -Command 'x' -Cwd $TestDrive -Env @{ STACK_TEST_CHILD = 'yes' }
        $script:seen | Should -Be 'yes'
        $env:STACK_TEST_CHILD | Should -BeNullOrEmpty
        $p.Id | Should -Be 7
    }
}

Describe 'Stop-StackServices' {
    It 'kills each tree then runs stop, in reverse start order' {
        $script:log = New-Object System.Collections.Generic.List[string]
        Mock Write-Host {}
        Mock Get-Process { [pscustomobject]@{ Id = $Id } }
        Mock Stop-StackProcessTree { $script:log.Add("kill $ProcessId"); @() }
        Mock Invoke-StackCommand { $script:log.Add("cmd $Command @ $Cwd"); 0 }
        $entries = @(
            [pscustomobject]@{ name = 'db'; processId = 1; cwd = 'C:\db'; stop = 'docker compose down' },
            [pscustomobject]@{ name = 'api'; processId = 2; cwd = 'C:\api'; stop = '' },
            [pscustomobject]@{ name = 'web'; processId = 3; cwd = 'C:\web'; stop = '' })
        Stop-StackServices -Entries $entries
        $script:log -join '|' | Should -Be 'kill 3|kill 2|kill 1|cmd docker compose down @ C:\db'
    }
    It 'skips a process that is not running but still runs its stop command' {
        $script:log = New-Object System.Collections.Generic.List[string]
        Mock Write-Host {}
        Mock Get-Process { $null }
        Mock Stop-StackProcessTree { $script:log.Add('kill') }
        Mock Invoke-StackCommand { $script:log.Add('cmd'); 0 }
        Stop-StackServices -Entries @([pscustomobject]@{ name = 'db'; processId = 1; cwd = 'C:\db'; stop = 'down' })
        $script:log -join '|' | Should -Be 'cmd'
    }
    It 'never kills a reused pid whose start time differs from the recorded one' {
        $script:log = New-Object System.Collections.Generic.List[string]
        Mock Write-Host {}
        Mock Get-Process { [pscustomobject]@{ Id = $Id; StartTime = [datetime]::UtcNow } }
        Mock Stop-StackProcessTree { $script:log.Add('kill') }
        Mock Invoke-StackCommand { $script:log.Add('cmd'); 0 }
        $old = [datetime]::UtcNow.AddDays(-1).ToString('o')
        Stop-StackServices -Entries @([pscustomobject]@{ name = 'api'; processId = 7; startedAt = $old; cwd = 'C:\api'; stop = '' })
        $script:log.Count | Should -Be 0
    }
    It 'kills a pid whose start time matches' {
        $script:log = New-Object System.Collections.Generic.List[string]
        $at = [datetime]::UtcNow.AddMinutes(-5)
        Mock Write-Host {}
        Mock Get-Process { [pscustomobject]@{ Id = $Id; StartTime = $at } }
        Mock Stop-StackProcessTree { $script:log.Add("kill $ProcessId"); @() }
        Stop-StackServices -Entries @([pscustomobject]@{ name = 'api'; processId = 7; startedAt = $at.ToString('o'); cwd = 'C:\api'; stop = '' })
        $script:log -join '|' | Should -Be 'kill 7'
    }
}

Describe 'Get-StackProfileFindings' {
    BeforeAll {
        $script:Root = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Path (Join-Path $script:Root 'api') -Force | Out-Null
        $script:Patterns = Join-Path $TestDrive 'secret-patterns.json'
        '{"patterns":[{"name":"aws-key","kind":"token","pattern":"AKIA[0-9A-Z]{16}"},{"name":"loose","kind":"heuristic","pattern":"x"}]}' | Set-Content $script:Patterns
        function Find([hashtable]$Stack, [string]$Patterns) {
            return Get-StackProfileFindings -Stack (ConvertTo-Stack $Stack) -Root $script:Root -SecretPatternsPath $Patterns
        }
    }
    It 'passes an empty stack and a valid one' {
        (Find @{ default = 'all'; presets = @{ all = @() }; services = @() }).Violations.Count | Should -Be 0
        $ok = @{ presets = @{ p = @('web') }; services = @(
                @{ name = 'api'; command = 'x'; cwd = 'api'; port = 5000; ready = @{ port = $true } },
                @{ name = 'web'; command = 'y'; port = 3000; dependsOn = @('api'); env = @{ K = '${env:HOME_X}' } }) }
        (Find $ok $script:Patterns).Violations.Count | Should -Be 0
    }
    It 'flags <Why>' -ForEach @(
        @{ Why = 'duplicate names'; Match = 'not unique'; Stack = @{ services = @(@{ name = 'a'; command = 'x' }, @{ name = 'a'; command = 'y' }) } }
        @{ Why = 'an empty command'; Match = 'no command'; Stack = @{ services = @(@{ name = 'a'; command = ' ' }) } }
        @{ Why = 'a missing cwd'; Match = "cwd 'ghost' does not exist"; Stack = @{ services = @(@{ name = 'a'; command = 'x'; cwd = 'ghost' }) } }
        @{ Why = 'a bad port'; Match = 'port must be an integer'; Stack = @{ services = @(@{ name = 'a'; command = 'x'; port = 70000 }) } }
        @{ Why = 'a duplicate port'; Match = 'port 80 is used by a'; Stack = @{ services = @(@{ name = 'a'; command = 'x'; port = 80 }, @{ name = 'b'; command = 'y'; port = 80 }) } }
        @{ Why = 'an unknown dependsOn'; Match = "unknown service 'ghost'"; Stack = @{ services = @(@{ name = 'a'; command = 'x'; dependsOn = @('ghost') }) } }
        @{ Why = 'a cycle'; Match = 'cycle'; Stack = @{ services = @(@{ name = 'a'; command = 'x'; dependsOn = @('b') }, @{ name = 'b'; command = 'y'; dependsOn = @('a') }) } }
        @{ Why = 'a preset naming an unknown service'; Match = "presets.p names unknown service 'nope'"; Stack = @{ presets = @{ p = @('nope') }; services = @(@{ name = 'a'; command = 'x' }) } }
        @{ Why = 'ready.port without a port'; Match = 'ready.port needs the service port'; Stack = @{ services = @(@{ name = 'a'; command = 'x'; ready = @{ port = $true } }) } }
        @{ Why = 'a literal secret in env'; Match = 'literal secret \(aws-key\)'; Stack = @{ services = @(@{ name = 'a'; command = 'x'; env = @{ K = ('AK' + 'IA' + 'ABCDEFGHIJKLMNOP') } }) } }
    ) {
        $r = Find $Stack $script:Patterns
        ($r.Violations -join "`n") | Should -Match $Match
    }
    It 'skips the secret check when secret-patterns.json is absent' {
        $stack = @{ services = @(@{ name = 'a'; command = 'x'; env = @{ K = ('AK' + 'IA' + 'ABCDEFGHIJKLMNOP') } }) }
        (Find $stack (Join-Path $TestDrive 'absent.json')).Violations.Count | Should -Be 0
    }
    It 'warns, not fails, on a legacy startCommand' {
        $r = Find @{ startCommand = 'npm run dev'; services = @() } $null
        $r.Violations.Count | Should -Be 0
        ($r.Warnings -join ' ') | Should -Match 'retired'
    }
}
