<#
.SYNOPSIS
    Shared helpers for the local stack launchers (Start/Stop/Swap-TicketStack.ps1).

.DESCRIPTION
    Dot-sourced. Do not run directly. Holds the profile.stacks contract: resolve a
    preset, order services by dependsOn, resolve env, wait for ready, start a service,
    stop a process tree, and validate the profile block. Stays ASCII-only and avoids
    PowerShell 7-only syntax so it parses on Windows PowerShell 5.1 too.
#>

Set-StrictMode -Version Latest

function Get-StackField {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if (-not $prop) { return $null }
    return $prop.Value
}

function Test-StackShouldProcess {
    # -Cmdlet is the caller's $PSCmdlet; $null (tests, helpers) always proceeds.
    param($Cmdlet, [string]$Target, [string]$Action)
    if ($null -eq $Cmdlet) { return $true }
    return [bool]$Cmdlet.ShouldProcess($Target, $Action)
}

function Test-StackPointsAtLauncher {
    param([string]$Command)
    if (-not $Command) { return $false }
    return ($Command -match 'Start-TicketStack\.ps1')
}

<#
.SYNOPSIS
    Returns @{ Services; Legacy; Warning } for a profile.stacks object. An old profile with
    stacks.startCommand and no services becomes one implicit service named "app".
#>
function Get-StackServiceList {
    param($Stack)
    $services = @()
    $list = Get-StackField $Stack 'services'
    if ($list) { $services = @($list) }
    $result = @{ Services = $services; Legacy = $false; Warning = $null }
    if ($services.Count -gt 0) { return $result }
    $legacy = [string](Get-StackField $Stack 'startCommand')
    if (-not $legacy -or $legacy -eq 'off' -or (Test-StackPointsAtLauncher $legacy)) { return $result }
    $result.Legacy = $true
    $result.Warning = "stacks.startCommand is retired. Treating it as one service named 'app'. Move it to stacks.services (see CUSTOMIZE.md, Stack recipes)."
    $result.Services = @([pscustomobject]@{ name = 'app'; command = $legacy })
    return $result
}

function Get-StackDependencyOrder {
    # Stable topological order: list order wins among services whose dependencies are met.
    param([object[]]$Services)
    $byName = @{}
    foreach ($s in $Services) { $byName[[string]$s.name] = $s }
    $remaining = New-Object System.Collections.Generic.List[object]
    foreach ($s in $Services) { $remaining.Add($s) }
    $done = @{}
    $ordered = New-Object System.Collections.Generic.List[object]
    while ($remaining.Count -gt 0) {
        $pick = $null
        foreach ($s in $remaining) {
            $deps = @(Get-StackField $s 'dependsOn' | Where-Object { $_ })
            $blocked = $false
            foreach ($d in $deps) {
                if (-not $byName.ContainsKey([string]$d)) { throw "Service '$($s.name)' dependsOn unknown service '$d'." }
                if (-not $done.ContainsKey([string]$d)) { $blocked = $true; break }
            }
            if (-not $blocked) { $pick = $s; break }
        }
        if (-not $pick) {
            $names = ($remaining | ForEach-Object { $_.name }) -join ', '
            throw "dependsOn cycle among services: $names."
        }
        $ordered.Add($pick)
        $done[[string]$pick.name] = $true
        [void]$remaining.Remove($pick)
    }
    return $ordered.ToArray()
}

<#
.SYNOPSIS
    Picks the services for a preset (plus the services they depend on) in start order.
.DESCRIPTION
    No -Preset: use stacks.default when it names a preset, else every service. A preset with
    an empty list means every service. "all" is always valid.
#>
function Resolve-StackSelection {
    param($Stack, [object[]]$Services, [string]$Preset)
    $presets = Get-StackField $Stack 'presets'
    if (-not $Preset) {
        $default = [string](Get-StackField $Stack 'default')
        if ($default -and $presets -and $presets.PSObject.Properties[$default]) { $Preset = $default }
    }
    $names = @($Services | ForEach-Object { [string]$_.name })
    $wanted = $names
    if ($Preset) {
        $listed = $null
        if ($presets -and $presets.PSObject.Properties[$Preset]) {
            $listed = @($presets.PSObject.Properties[$Preset].Value | Where-Object { $_ })
        } elseif ($Preset -ne 'all') {
            $known = @()
            if ($presets) { $known = @($presets.PSObject.Properties.Name) }
            throw "Unknown preset '$Preset'. Known: $($known -join ', ')."
        }
        if ($listed -and $listed.Count -gt 0) { $wanted = $listed }
    }
    foreach ($n in $wanted) {
        if ($names -notcontains [string]$n) { throw "Preset '$Preset' names unknown service '$n'." }
    }
    # Pull in dependencies so a subset still starts what it needs.
    $include = @{}
    $queue = New-Object System.Collections.Generic.Queue[string]
    foreach ($n in $wanted) { $queue.Enqueue([string]$n) }
    while ($queue.Count -gt 0) {
        $n = $queue.Dequeue()
        if ($include.ContainsKey($n)) { continue }
        $include[$n] = $true
        $svc = $Services | Where-Object { [string]$_.name -eq $n } | Select-Object -First 1
        foreach ($d in @(Get-StackField $svc 'dependsOn' | Where-Object { $_ })) {
            if ($names -notcontains [string]$d) { throw "Service '$n' dependsOn unknown service '$d'." }
            $queue.Enqueue([string]$d)
        }
    }
    $subset = @($Services | Where-Object { $include.ContainsKey([string]$_.name) })
    return @(Get-StackDependencyOrder -Services $subset)
}

function Resolve-StackEnv {
    # Returns a hashtable of name -> value, with ${env:NAME} replaced from this environment.
    param($Env)
    $out = @{}
    if ($null -eq $Env) { return $out }
    foreach ($p in $Env.PSObject.Properties) {
        $value = [string]$p.Value
        $pattern = '\$\{env:([A-Za-z_][A-Za-z0-9_]*)\}'
        $resolved = [regex]::Replace($value, $pattern, {
                param($m)
                $v = [Environment]::GetEnvironmentVariable($m.Groups[1].Value)
                if ($null -eq $v) { throw "env '$($p.Name)' references `${env:$($m.Groups[1].Value)}, which is not set in your environment." }
                return $v
            })
        $out[$p.Name] = $resolved
    }
    return $out
}

function Test-StackPortOpen {
    # Tries IPv4 then IPv6 loopback, each bounded by TimeoutMs. A dev server may bind either.
    param([int]$Port, [int]$TimeoutMs = 1000)
    foreach ($addr in @([System.Net.IPAddress]::Loopback, [System.Net.IPAddress]::IPv6Loopback)) {
        $client = New-Object System.Net.Sockets.TcpClient($addr.AddressFamily)
        try {
            $task = $client.ConnectAsync($addr, $Port)
            if ($task.Wait($TimeoutMs) -and $client.Connected) { return $true }
        } catch {
            # refused or unreachable on this address: try the next
        } finally {
            $client.Dispose()
        }
    }
    return $false
}

function Test-StackUrlUp {
    param([string]$Url)
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -SkipHttpErrorCheck -SkipCertificateCheck
        return ([int]$r.StatusCode -lt 400)
    } catch {
        return $false
    }
}

function Wait-StackReady {
    param(
        [Parameter(Mandatory)][string]$Name,
        $Ready,
        $Port,
        [int]$PollMs = 500
    )
    if ($null -eq $Ready) { return }
    $timeout = Get-StackField $Ready 'timeoutSec'
    if (-not $timeout) { $timeout = 60 }
    $url = [string](Get-StackField $Ready 'url')
    $usePort = [bool](Get-StackField $Ready 'port')
    if (-not $url -and -not $usePort) { return }
    if ($usePort -and -not $Port) { throw "Service '$Name' ready.port is true but the service has no port." }
    $deadline = (Get-Date).AddSeconds([int]$timeout)
    while ($true) {
        $up = $false
        if ($url) { $up = Test-StackUrlUp -Url $url } else { $up = Test-StackPortOpen -Port ([int]$Port) }
        if ($up) { return }
        if ((Get-Date) -ge $deadline) {
            $what = if ($url) { $url } else { "port $Port" }
            throw "Service '$Name' was not ready at $what within $timeout s."
        }
        Start-Sleep -Milliseconds $PollMs
    }
}

function Get-StackProcessTable {
    # One snapshot of pid -> parent pid for every process.
    $rows = @()
    if ($env:OS -eq 'Windows_NT') {
        foreach ($p in @(Get-CimInstance -ClassName Win32_Process -Property ProcessId, ParentProcessId)) {
            $rows += [pscustomobject]@{ Id = [int]$p.ProcessId; Parent = [int]$p.ParentProcessId }
        }
    } else {
        foreach ($line in @(& /bin/ps -A -o 'pid=,ppid=')) {
            $f = ([string]$line).Trim() -split '\s+'
            if ($f.Count -ge 2) { $rows += [pscustomobject]@{ Id = [int]$f[0]; Parent = [int]$f[1] } }
        }
    }
    return $rows
}

function Get-StackDescendantIds {
    # Deepest first, so killing in order never orphans a child; the root is last.
    param([int]$RootId, [object[]]$Table)
    $kids = @{}
    foreach ($r in $Table) {
        if ($r.Id -eq $r.Parent) { continue }
        if (-not $kids.ContainsKey($r.Parent)) { $kids[$r.Parent] = New-Object System.Collections.Generic.List[int] }
        $kids[$r.Parent].Add($r.Id)
    }
    $out = New-Object System.Collections.Generic.List[int]
    $seen = @{}
    function Add-Post([int]$id) {
        if ($seen.ContainsKey($id)) { return }
        $seen[$id] = $true
        if ($kids.ContainsKey($id)) { foreach ($k in $kids[$id]) { Add-Post $k } }
        $out.Add($id)
    }
    Add-Post $RootId
    return @($out)
}

function Stop-StackProcessTree {
    param([Parameter(Mandatory)][int]$ProcessId)
    $ids = @(Get-StackDescendantIds -RootId $ProcessId -Table @(Get-StackProcessTable))
    foreach ($id in $ids) {
        Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
    }
    return $ids
}

function Invoke-StackCommand {
    # Runs a setup or stop command to completion in its cwd. Returns the exit code.
    param([Parameter(Mandatory)][string]$Command, [Parameter(Mandatory)][string]$Cwd)
    $p = Start-Process -FilePath 'pwsh' -WorkingDirectory $Cwd -Wait -PassThru -NoNewWindow -ArgumentList @(
        '-NoProfile', '-Command', $Command
    )
    return [int]$p.ExitCode
}

function Start-StackProcess {
    # Starts one long-running service. Env is applied to this process for the spawn only,
    # then restored, so values never appear on a command line.
    param([Parameter(Mandatory)][string]$Command, [Parameter(Mandatory)][string]$Cwd, [hashtable]$Env)
    $saved = @{}
    foreach ($k in @($Env.Keys)) {
        $saved[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, [string]$Env[$k])
    }
    try {
        return Start-Process -FilePath 'pwsh' -WorkingDirectory $Cwd -PassThru -ArgumentList @(
            '-NoProfile', '-Command', $Command
        )
    } finally {
        foreach ($k in @($saved.Keys)) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
}

function Test-StackPortListening {
    param([int]$Port)
    if (-not (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) { return (Test-StackPortOpen -Port $Port -TimeoutMs 300) }
    $listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    return $listeners.Count -gt 0
}

function Write-StackState {
    param([string]$StatePath, [object[]]$Entries)
    ConvertTo-Json -InputObject @($Entries) -Depth 5 | Set-Content -LiteralPath $StatePath -Encoding utf8
}

function Resolve-StackCwd {
    param([string]$Cwd, [string]$RepoRoot)
    if (-not $Cwd) { $Cwd = '.' }
    if (-not [System.IO.Path]::IsPathRooted($Cwd)) { return (Join-Path $RepoRoot $Cwd) }
    return $Cwd
}

<#
.SYNOPSIS
    Starts the ordered services. Returns the list of started entries; throws on a failed
    setup or a service that never becomes ready (state already holds what did start).
#>
function Start-StackServices {
    param(
        [object[]]$Services,
        [string]$RepoRoot,
        [string]$StatePath,
        [switch]$Setup,
        $Cmdlet
    )
    $started = @()
    $step = 0
    foreach ($service in $Services) {
        $step++
        $name = [string](Get-StackField $service 'name')
        $command = [string](Get-StackField $service 'command')
        if (-not $name) { throw "stacks.services[$($step - 1)] is missing name." }
        if (-not $command) { throw "stacks.services[$($step - 1)] ($name) is missing command." }
        $cwd = Resolve-StackCwd ([string](Get-StackField $service 'cwd')) $RepoRoot
        $port = Get-StackField $service 'port'
        $url = Get-StackField $service 'url'
        $setupCommand = [string](Get-StackField $service 'setup')
        $stopCommand = [string](Get-StackField $service 'stop')

        if ($port -and (Test-StackPortListening -Port ([int]$port))) {
            Write-Host "[SKIP] $name already listening on port $port"
            continue
        }
        $target = "$name : $command"
        Write-Host "[START] $step. $target"
        if ($url) { Write-Host "        $url" }
        if (-not (Test-StackShouldProcess $Cmdlet $target 'Start service')) { continue }
        if (-not (Test-Path -LiteralPath $cwd)) { throw "Working directory not found for ${name}: $cwd" }
        $envMap = Resolve-StackEnv (Get-StackField $service 'env')

        if ($Setup -and $setupCommand) {
            Write-Host "[SETUP] $name : $setupCommand"
            $code = Invoke-StackCommand -Command $setupCommand -Cwd $cwd
            if ($code -ne 0) { throw "Setup for $name exited $code." }
        }
        $proc = Start-StackProcess -Command $command -Cwd $cwd -Env $envMap
        $startedAt = $null
        try { $startedAt = $proc.StartTime.ToUniversalTime().ToString('o') } catch { Write-Verbose "No start time for pid $($proc.Id)" }
        $started += [pscustomobject]@{
            name      = $name
            processId = $proc.Id
            startedAt = $startedAt
            port      = $port
            url       = $url
            cwd       = $cwd
            stop      = $stopCommand
        }
        if ($StatePath) { Write-StackState -StatePath $StatePath -Entries $started }
        Wait-StackReady -Name $name -Ready (Get-StackField $service 'ready') -Port $port
    }
    return $started
}

<#
.SYNOPSIS
    Stops recorded services in reverse start order: kill the process tree, then run `stop`.
#>
function Test-StackSameProcess {
    # True when a live process is the one Start recorded: same start time within 2 seconds.
    # A state entry without startedAt (written before it was recorded) is trusted as before.
    param($Process, [string]$StartedAt)
    if (-not $StartedAt) { return $true }
    $recorded = [datetime]::MinValue
    $styles = [Globalization.DateTimeStyles]::RoundtripKind
    if (-not [datetime]::TryParse($StartedAt, [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$recorded)) { return $false }
    try { $actual = $Process.StartTime.ToUniversalTime() } catch { return $false }
    return [math]::Abs(($actual - $recorded.ToUniversalTime()).TotalSeconds) -le 2
}

function Stop-StackServices {
    param([object[]]$Entries, $Cmdlet)
    $list = @($Entries)
    [array]::Reverse($list)
    foreach ($entry in $list) {
        $name = [string](Get-StackField $entry 'name')
        $procId = Get-StackField $entry 'processId'
        if ($procId) {
            $live = Get-Process -Id ([int]$procId) -ErrorAction SilentlyContinue
            if ($live -and -not (Test-StackSameProcess -Process $live -StartedAt ([string](Get-StackField $entry 'startedAt')))) {
                # The pid was reused (a reboot, or the service exited long ago): not ours to kill.
                Write-Host "[SKIP] $name pid $procId is now a different process"
            } elseif ($live) {
                if (Test-StackShouldProcess $Cmdlet "$name pid $procId" 'Stop process tree') {
                    [void](Stop-StackProcessTree -ProcessId ([int]$procId))
                    Write-Host "[STOP] $name pid $procId"
                }
            } else {
                Write-Host "[SKIP] $name pid $procId is not running"
            }
        }
        $stopCommand = [string](Get-StackField $entry 'stop')
        if ($stopCommand) {
            $cwd = [string](Get-StackField $entry 'cwd')
            if (-not $cwd) { $cwd = (Get-Location).Path }
            if (Test-StackShouldProcess $Cmdlet "$name : $stopCommand" 'Run stop command') {
                Write-Host "[STOP] $name : $stopCommand"
                $code = Invoke-StackCommand -Command $stopCommand -Cwd $cwd
                if ($code -ne 0) { Write-Host "[WARN] stop command for $name exited $code" }
            }
        }
    }
}

function Test-StackEnvPlaceholderOnly {
    param([string]$Value)
    return ($Value -notmatch '^\s*$' -and ([regex]::Replace($Value, '\$\{env:[A-Za-z_][A-Za-z0-9_]*\}', '') -notmatch '\S'))
}

<#
.SYNOPSIS
    Checks the profile.stacks block. Returns @{ Violations; Warnings } (strings).
.PARAMETER SecretPatternsPath
    Optional scripts/ticket/secret-patterns.json ({ patterns: [{ name, kind, pattern }] });
    env values are checked against the token patterns. Skipped when absent.
#>
function Get-StackProfileFindings {
    param($Stack, [string]$Root, [string]$SecretPatternsPath)
    $v = New-Object System.Collections.Generic.List[string]
    $w = New-Object System.Collections.Generic.List[string]
    $result = @{ Violations = $v; Warnings = $w }
    if ($null -eq $Stack) { $v.Add('profile: stacks is missing'); return $result }

    if (Get-StackField $Stack 'startCommand') {
        $legacy = [string](Get-StackField $Stack 'startCommand')
        if ($legacy -ne 'off') { $w.Add('profile: stacks.startCommand is retired -- move it to stacks.services (CUSTOMIZE.md, Stack recipes)') }
    }
    $services = @()
    $rawList = Get-StackField $Stack 'services'
    if ($rawList) { $services = @($rawList) }

    $patterns = @()
    if ($SecretPatternsPath -and (Test-Path -LiteralPath $SecretPatternsPath)) {
        # { patterns: [{ name, kind, pattern }] }; env values get the token patterns, as commits do.
        try {
            $doc = Get-Content -LiteralPath $SecretPatternsPath -Raw | ConvertFrom-Json
            $all = if ($doc.PSObject.Properties.Name -contains 'patterns') { @($doc.patterns) } else { @($doc) }
            $patterns = @($all | Where-Object { -not ($_.PSObject.Properties.Name -contains 'kind') -or $_.kind -eq 'token' })
        } catch { $patterns = @() }
    }

    $seenNames = @{}
    $seenPorts = @{}
    $index = -1
    foreach ($s in $services) {
        $index++
        $label = "stacks.services[$index]"
        $name = [string](Get-StackField $s 'name')
        if (-not $name.Trim()) { $v.Add("profile: $label has no name"); $name = "#$index" } else { $label = "stacks.services[$name]" }
        if ($seenNames.ContainsKey($name)) { $v.Add("profile: $label name is not unique") }
        $seenNames[$name] = $true
        if (-not ([string](Get-StackField $s 'command')).Trim()) { $v.Add("profile: $label has no command") }
        foreach ($f in @('setup', 'stop')) {
            $val = Get-StackField $s $f
            if ($null -ne $val -and $val -isnot [string]) { $v.Add("profile: $label.$f must be a string") }
        }
        $cwd = [string](Get-StackField $s 'cwd')
        if (-not $cwd) { $cwd = '.' }
        $cwdFull = Resolve-StackCwd $cwd $Root
        if (-not (Test-Path -LiteralPath $cwdFull -PathType Container)) { $v.Add("profile: $label cwd '$cwd' does not exist") }
        $port = Get-StackField $s 'port'
        if ($null -ne $port) {
            $n = 0
            if (($port -is [int] -or $port -is [long]) -and [int]$port -ge 1 -and [int]$port -le 65535) {
                $n = [int]$port
                if ($seenPorts.ContainsKey($n)) { $v.Add("profile: $label port $n is used by $($seenPorts[$n])") } else { $seenPorts[$n] = $name }
            } else {
                $v.Add("profile: $label port must be an integer 1-65535")
            }
        }
        $ready = Get-StackField $s 'ready'
        if ($null -ne $ready) {
            $rurl = Get-StackField $ready 'url'
            $rport = Get-StackField $ready 'port'
            if (-not $rurl -and $rport -ne $true) { $v.Add("profile: $label ready needs { port: true } or { url }") }
            if ($rport -eq $true -and $null -eq $port) { $v.Add("profile: $label ready.port needs the service port") }
            $rt = Get-StackField $ready 'timeoutSec'
            if ($null -ne $rt -and (($rt -isnot [int] -and $rt -isnot [long]) -or $rt -lt 1)) { $v.Add("profile: $label ready.timeoutSec must be a positive integer") }
        }
        $envObj = Get-StackField $s 'env'
        if ($null -ne $envObj) {
            foreach ($p in $envObj.PSObject.Properties) {
                $text = [string]$p.Value
                if ($p.Value -isnot [string]) { $v.Add("profile: $label env.$($p.Name) must be a string"); continue }
                if (Test-StackEnvPlaceholderOnly $text) { continue }
                foreach ($sp in $patterns) {
                    $pat = Get-StackField $sp 'pattern'
                    if ($pat -and ($text -match $pat)) { $v.Add("profile: $label env.$($p.Name) looks like a literal secret ($(Get-StackField $sp 'name')) -- use `${env:NAME}"); break }
                }
            }
        }
    }

    foreach ($s in $services) {
        $name = [string](Get-StackField $s 'name')
        foreach ($d in @(Get-StackField $s 'dependsOn' | Where-Object { $_ })) {
            if (-not $seenNames.ContainsKey([string]$d)) { $v.Add("profile: stacks.services[$name] dependsOn unknown service '$d'") }
        }
    }
    if ($v.Count -eq 0 -and $services.Count -gt 0) {
        try { [void](Get-StackDependencyOrder -Services $services) } catch { $v.Add("profile: $($_.Exception.Message)") }
    }

    $presets = Get-StackField $Stack 'presets'
    if ($presets) {
        foreach ($p in $presets.PSObject.Properties) {
            if ($p.Value -isnot [array]) { $v.Add("profile: stacks.presets.$($p.Name) must be an array of service names"); continue }
            foreach ($n in @($p.Value)) {
                if (-not $seenNames.ContainsKey([string]$n)) { $v.Add("profile: stacks.presets.$($p.Name) names unknown service '$n'") }
            }
        }
    }
    return $result
}
