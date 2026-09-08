<#
.SYNOPSIS
    Thin start-stack wrapper for the template. Reads profile.json stacks.startCommand and executes it.

.DESCRIPTION
    Customize for your project. The default reads profile.json from the .cursor folder and runs
    stacks.startCommand. Replace with your actual stack launcher (IIS, Docker, npm scripts, etc.).

.PARAMETER Ticket
    Optional ticket ID (e.g. TICKET-42). Used for logging only.

.PARAMETER Force
    Skip the active-stack ownership check.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Ticket,
    [switch]$Force
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$profilePath = Join-Path $PSScriptRoot "..\..\profile.json"
if (-not (Test-Path $profilePath)) {
    Write-Error "profile.json not found at $profilePath. Please create it from the template."
    exit 1
}

$profile = Get-Content $profilePath -Raw | ConvertFrom-Json
$startCmd = $profile.stacks.startCommand

if (-not $startCmd) {
    Write-Error "profile.json does not define stacks.startCommand. Edit profile.json to set it."
    exit 1
}

Write-Host "[START] Ticket: $Ticket | Command: $startCmd"

if ($PSCmdlet.ShouldProcess($startCmd, "Execute start command")) {
    Invoke-Expression $startCmd
}
