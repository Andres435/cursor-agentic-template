<#
.SYNOPSIS
    Record the engineering-mode lane mix on the ticket manifest.

.DESCRIPTION
    Writes manifest.lanes, for example f2/s1/d0 inline:d3.
    /complete-task copies it into the ledger Lanes column.
    Do not invent a mix for a ticket that did not run engineering mode.
    Pass -Lanes '' only when engineering mode was off; the cell stays blank.

.PARAMETER Ticket
    Work item, with or without the WI prefix.

.PARAMETER Lanes
    Short mix string. No pipe characters.

.PARAMETER Root
    Override the workflow repo root (tests).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ticket,
    [Parameter(Mandatory)][string]$Lanes,
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Lanes -match '\|') { throw "Lanes must not contain '|'. Got: $Lanes" }
if ($Lanes.Length -gt 80) { throw "Lanes must be 80 characters or fewer." }

. (Join-Path (Join-Path $PSScriptRoot 'lib') 'ManifestFields.ps1')

$Key = Get-TicketKeyFromRaw -Ticket $Ticket
$RepoRoot = if ($Root) { $Root } else { Get-CursorRepoRoot -FromScriptRoot $PSScriptRoot }
$manifestPath = Get-TicketManifestFile -RepoRoot $RepoRoot -TicketKey $Key
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Manifest not found: $manifestPath"
}

Merge-TicketManifestFields -ManifestPath $manifestPath -Patch @{ lanes = $Lanes.Trim() }
Write-Host "Wrote lanes=$($Lanes.Trim()) on $manifestPath" -ForegroundColor Green
