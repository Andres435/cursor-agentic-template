#Requires -Version 7
<#
.SYNOPSIS
    Starts the local stack described in profile.json.

.DESCRIPTION
    Prefer stacks.services (one object per app: name, command, cwd, port, url).
    /start-new-project writes that list. When it is empty, run stacks.startCommand
    unless that command is this script.

.PARAMETER Ticket
    Ticket id. Recorded as the stack owner when supplied.

.PARAMETER Force
    Take the stack owner even when another ticket holds it.

.PARAMETER ProfilePath
    profile.json to read. Defaults to the repo root beside this scripts folder.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Ticket,
    [switch]$Force,
    [string]$ProfilePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ServiceField {
    param($Service, [string]$Name)
    $prop = $Service.PSObject.Properties[$Name]
    if (-not $prop) { return $null }
    return $prop.Value
}

function Test-LocalPortListening {
    param([int]$Port)
    $listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    return $listeners.Count -gt 0
}

if (-not $ProfilePath) {
    $ProfilePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'profile.json'
}
if (-not (Test-Path -LiteralPath $ProfilePath)) {
    Write-Error "profile.json not found at $ProfilePath."
    exit 1
}

$profileJson = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
$stack = $profileJson.stacks
if (-not $stack) {
    Write-Error 'profile.json does not define stacks.'
    exit 1
}

$services = @()
if ($stack.PSObject.Properties.Name -contains 'services' -and $stack.services) {
    $services = @($stack.services)
}
$startCommand = $null
if ($stack.PSObject.Properties.Name -contains 'startCommand') {
    $startCommand = [string]$stack.startCommand
}

$self = $PSCommandPath
$pointsAtSelf = $startCommand -and (
    $startCommand -eq './scripts/runtime/Start-TicketStack.ps1' -or
    $startCommand -eq '.\scripts\runtime\Start-TicketStack.ps1' -or
    ((Test-Path -LiteralPath $startCommand) -and ((Resolve-Path -LiteralPath $startCommand).Path -eq $self))
)

if ($services.Count -eq 0) {
    if (-not $startCommand -or $startCommand -eq 'off' -or $pointsAtSelf) {
        Write-Error 'Stack is disabled or has no services. Fill profile.stacks.services (see CUSTOMIZE.md).'
        exit 1
    }
    Write-Host "[START] Ticket: $Ticket | Command: $startCommand"
    if ($PSCmdlet.ShouldProcess($startCommand, 'Execute start command')) {
        Invoke-Expression $startCommand
    }
    exit 0
}

if ($Ticket) {
    $owner = Join-Path $PSScriptRoot 'Set-ActiveStack.ps1'
    $ownerArgs = @('-File', $owner, '-Ticket', $Ticket)
    if ($Force) { $ownerArgs += '-Force' }
    if ($PSCmdlet.ShouldProcess($Ticket, 'Claim stack owner')) {
        & pwsh @ownerArgs
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$started = @()
$step = 0
foreach ($service in $services) {
    $step++
    $name = Get-ServiceField $service 'name'
    if (-not $name) { $name = "service-$step" }
    $command = Get-ServiceField $service 'command'
    if (-not $command) {
        Write-Error "stacks.services[$($step - 1)] ($name) is missing command."
        exit 1
    }
    $cwd = Get-ServiceField $service 'cwd'
    if (-not $cwd) { $cwd = '.' }
    if (-not [System.IO.Path]::IsPathRooted($cwd)) {
        $cwd = Join-Path $repoRoot $cwd
    }
    $portValue = Get-ServiceField $service 'port'
    $url = Get-ServiceField $service 'url'

    if ($portValue -and (Test-LocalPortListening -Port ([int]$portValue))) {
        Write-Host "[SKIP] $name already listening on port $portValue"
        continue
    }

    $target = "$name : $command"
    Write-Host "[START] $step. $target"
    if ($url) { Write-Host "        $url" }
    if (-not $PSCmdlet.ShouldProcess($target, 'Start service')) { continue }
    if (-not (Test-Path -LiteralPath $cwd)) {
        Write-Error "Working directory not found for ${name}: $cwd"
        exit 1
    }
    $proc = Start-Process -FilePath 'pwsh' -WorkingDirectory $cwd -PassThru -ArgumentList @(
        '-NoProfile', '-Command', [string]$command
    )
    $started += [pscustomobject]@{
        name = [string]$name
        processId = $proc.Id
        port = $portValue
        url  = $url
    }
}

if ($PSCmdlet.ShouldProcess('stack state', 'Write')) {
    $statePath = Join-Path $PSScriptRoot '.stack-services.state.json'
    $started | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $statePath -Encoding utf8
}

Write-Host "[PASS] Started $($started.Count) service(s)."
foreach ($entry in $started) {
    if ($entry.url) { Write-Host "  $($entry.url)" }
}
exit 0
