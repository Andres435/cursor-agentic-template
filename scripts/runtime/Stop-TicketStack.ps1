#Requires -Version 7
<#
.SYNOPSIS
    Stops the services this repo's Start-TicketStack.ps1 recorded, then releases the owner.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$statePath = Join-Path $PSScriptRoot '.stack-services.state.json'
if (Test-Path -LiteralPath $statePath) {
    $entries = @(Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json)
    foreach ($entry in $entries) {
        $procId = $entry.processId
        if (-not $procId) { continue }
        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if (-not $proc) {
            Write-Host "[SKIP] $($entry.name) pid $procId is not running"
            continue
        }
        if ($PSCmdlet.ShouldProcess("$($entry.name) pid $procId", 'Stop')) {
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            Write-Host "[STOP] $($entry.name) pid $procId"
        }
    }
    if ($PSCmdlet.ShouldProcess($statePath, 'Remove state')) {
        Remove-Item -LiteralPath $statePath -Force
    }
} else {
    Write-Host '[SKIP] No recorded services.'
}

$owner = Join-Path $PSScriptRoot 'Set-ActiveStack.ps1'
if ($PSCmdlet.ShouldProcess('active stack', 'Clear owner')) {
    & pwsh -NoProfile -File $owner -Clear
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
exit 0
