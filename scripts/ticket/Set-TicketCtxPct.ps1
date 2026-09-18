<#
.SYNOPSIS
    Record one chat's context-window occupancy on the ticket manifest.

.DESCRIPTION
    start  → ctxPct.start (ledger CtxS%) at the end of the /start-ticket chat
    review → ctxPct.review (ledger CtxR%) at the end of /review-changes
    close  → ctxPct.close (ledger Ctx%) at /complete-task
    /implement is not recorded.

.PARAMETER Ticket
    Work item, with or without the WI prefix.

.PARAMETER Phase
    start | review | close

.PARAMETER Percent
    0–100 occupancy of that chat.

.PARAMETER Root
    Override the .cursor repo root (tests).

.EXAMPLE
    .\Set-TicketCtxPct.ps1 -Ticket WI21961 -Phase start -Percent 81
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ticket,
    [Parameter(Mandatory)][ValidateSet('start', 'review', 'close')][string]$Phase,
    [Parameter(Mandatory)][ValidateRange(0, 100)][int]$Percent,
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path (Join-Path $PSScriptRoot 'lib') 'ManifestFields.ps1')

$Key = Get-TicketKeyFromRaw -Ticket $Ticket
$RepoRoot = if ($Root) { $Root } else { Get-CursorRepoRoot -FromScriptRoot $PSScriptRoot }
$manifestPath = Get-TicketManifestFile -RepoRoot $RepoRoot -TicketKey $Key
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Manifest not found: $manifestPath"
}

$obj = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$ctxHash = [ordered]@{}
if ($obj.PSObject.Properties.Name -contains 'ctxPct' -and $obj.ctxPct) {
    foreach ($p in $obj.ctxPct.PSObject.Properties) {
        $ctxHash[$p.Name] = $p.Value
    }
}
$ctxHash[$Phase] = $Percent
$ctx = New-Object PSObject
foreach ($k in $ctxHash.Keys) {
    $ctx | Add-Member -NotePropertyName $k -NotePropertyValue $ctxHash[$k]
}

Merge-TicketManifestFields -ManifestPath $manifestPath -Patch @{ ctxPct = $ctx }
Write-Host "Wrote ctxPct.$Phase=$Percent on $manifestPath" -ForegroundColor Green
