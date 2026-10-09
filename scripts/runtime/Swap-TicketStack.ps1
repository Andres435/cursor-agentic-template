#Requires -Version 7
<#
.SYNOPSIS
    Moves the one local stack to another ticket: stop, re-claim the owner, start.

.PARAMETER Ticket
    The ticket that takes the stack.

.PARAMETER Preset
    Preset to start for the target ticket (see stacks.presets).

.PARAMETER Setup
    Also run each service's setup command on the new start.

.EXAMPLE
    ./scripts/runtime/Swap-TicketStack.ps1 -Ticket TICKET-13 -Preset web
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Ticket,
    [string]$Preset,
    [switch]$Setup,
    [string]$ProfilePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param([string]$Script, [string[]]$StepArgs)
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot $Script) @StepArgs
    if ($LASTEXITCODE -ne 0) { Write-Host "[FAIL] $Script exited $LASTEXITCODE" -ForegroundColor Red; exit $LASTEXITCODE }
}

if (-not $PSCmdlet.ShouldProcess($Ticket, 'Swap stack')) { exit 0 }
Invoke-Step 'Stop-TicketStack.ps1' @('-Force')
Invoke-Step 'Set-ActiveStack.ps1' @('-Ticket', $Ticket, '-Force')
$startArgs = @('-Ticket', $Ticket)
if ($Preset) { $startArgs += @('-Preset', $Preset) }
if ($Setup) { $startArgs += '-Setup' }
if ($ProfilePath) { $startArgs += @('-ProfilePath', $ProfilePath) }
Invoke-Step 'Start-TicketStack.ps1' $startArgs
exit 0
