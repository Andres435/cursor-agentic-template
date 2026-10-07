#Requires -Version 7
<#
.SYNOPSIS
    Record which ticket owns the one local app stack.
#>
[CmdletBinding(DefaultParameterSetName = 'Set')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Set')][string]$Ticket,
    [Parameter(Mandatory, ParameterSetName = 'Clear')][switch]$Clear,
    [switch]$Force
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) "lib/ActiveStack.ps1")

if ($Clear) {
    Clear-ActiveStackState -ScriptRoot $PSScriptRoot
    Write-Host "Released active-stack ownership."
    return
}
$active = Get-ActiveStackState -ScriptRoot $PSScriptRoot
if ($active -and $active.Ticket -ne $Ticket -and -not $Force) {
    Write-Host "$($active.Ticket) already owns the stack. Pass -Force to take it."
    exit 1
}
Set-ActiveStackState -ScriptRoot $PSScriptRoot -Ticket $Ticket
Write-Host "$Ticket now owns the local app stack."
