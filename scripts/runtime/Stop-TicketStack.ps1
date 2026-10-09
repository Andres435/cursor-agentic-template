#Requires -Version 7
<#
.SYNOPSIS
    Stops the services Start-TicketStack.ps1 recorded, then releases the owner.

.DESCRIPTION
    Services stop in reverse start order. Each one has its whole process tree killed
    (children first), then its stop command runs in its cwd (for example docker compose down).

.PARAMETER Ticket
    Ticket asking to stop. When another ticket owns the stack the stop is refused unless -Force.

.PARAMETER Force
    Stop even when another ticket owns the stack.

.EXAMPLE
    ./scripts/runtime/Stop-TicketStack.ps1 -Ticket TICKET-12
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Ticket,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib/StackServices.ps1')
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib/ActiveStack.ps1')

if ($Ticket -and -not $Force) {
    $holder = Test-ActiveStackConflict -ScriptRoot $PSScriptRoot -Ticket $Ticket
    if ($holder) {
        Write-Host "[FAIL] $holder owns the stack. Pass -Force to stop it." -ForegroundColor Red
        exit 1
    }
}

$statePath = Join-Path $PSScriptRoot '.stack-services.state.json'
if (Test-Path -LiteralPath $statePath) {
    $entries = @(Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json)
    Stop-StackServices -Entries $entries -Cmdlet $PSCmdlet
    if ($PSCmdlet.ShouldProcess($statePath, 'Remove state')) {
        Remove-Item -LiteralPath $statePath -Force
    }
} else {
    Write-Host '[SKIP] No recorded services.'
}

if ($PSCmdlet.ShouldProcess('active stack', 'Clear owner')) {
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Set-ActiveStack.ps1') -Clear
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
exit 0
