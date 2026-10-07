#Requires -Version 7
<#
.SYNOPSIS
    Record one chat's context-window occupancy on the ticket manifest (report-context).

.DESCRIPTION
    start  → ctxPct.start (ledger CtxS%) at the end of the /start-ticket chat
    review → ctxPct.review (ledger CtxR%) at the end of /review-changes
    close  → ctxPct.close (ledger Ctx%) at /complete-task
    /implement is not recorded.

    Omit -Percent to use the value the IDE hook measured for this chat
    (scripts/.ctx-usage.json, written by hooks/core/context-usage.js): the entry for
    TMO_SESSION_ID when set, else the newest one under six hours old. With no
    measurement and no -Percent, nothing is written -- a blank is honest, a guess is
    not. ctxPctSource.<phase> records measured or reported.

.PARAMETER Ticket
    Work item, with or without the ticket prefix.

.PARAMETER Phase
    start | review | close

.PARAMETER Percent
    0–100 occupancy, only when you can read a real number. Recorded as reported.

.PARAMETER Root
    Override the workflow repo root (tests).

.EXAMPLE
    .\Set-TicketCtxPct.ps1 -Ticket TICKET-42 -Phase start
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ticket,
    [Parameter(Mandatory)][ValidateSet('start', 'review', 'close')][string]$Phase,
    [ValidateRange(0, 100)][int]$Percent,
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path (Join-Path $PSScriptRoot 'lib') 'ManifestFields.ps1')

function Get-MeasuredCtxPct {
    $file = if ($env:TMO_CTX_USAGE_FILE) { $env:TMO_CTX_USAGE_FILE }
            else { Join-Path (Split-Path $PSScriptRoot -Parent) '.ctx-usage.json' }
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    try { $data = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
    $entry = $null
    $session = $env:TMO_SESSION_ID
    if ($session -and $data.PSObject.Properties.Name -contains 'sessions' -and $data.sessions -and
        $data.sessions.PSObject.Properties.Name -contains $session) {
        $entry = $data.sessions.$session
    } elseif ($data.PSObject.Properties.Name -contains 'latest' -and $data.latest) {
        $entry = $data.latest
        $age = [DateTime]::UtcNow - ([DateTime]::Parse([string]$entry.at)).ToUniversalTime()
        if ($age.TotalHours -gt 6) { $entry = $null }
    }
    if (-not $entry) { return $null }
    return [int]$entry.pct
}

$Key = Get-TicketKeyFromRaw -Ticket $Ticket
$RepoRoot = if ($Root) { $Root } else { Get-CursorRepoRoot -FromScriptRoot $PSScriptRoot }
$manifestPath = Get-TicketManifestFile -RepoRoot $RepoRoot -TicketKey $Key
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Manifest not found: $manifestPath"
}

if ($PSBoundParameters.ContainsKey('Percent')) {
    $value = $Percent
    $source = 'reported'
} else {
    $value = Get-MeasuredCtxPct
    $source = 'measured'
    if ($null -eq $value) {
        Write-Host "No measured context for this chat; ctxPct.$Phase left blank (pass -Percent only with a real number)." -ForegroundColor Yellow
        return
    }
}

$obj = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
function ConvertTo-PhaseObject {
    param($Existing, [string]$Name, $Value)
    $hash = [ordered]@{}
    if ($Existing) { foreach ($p in $Existing.PSObject.Properties) { $hash[$p.Name] = $p.Value } }
    $hash[$Name] = $Value
    $out = New-Object PSObject
    foreach ($k in $hash.Keys) { $out | Add-Member -NotePropertyName $k -NotePropertyValue $hash[$k] }
    return $out
}
$priorCtx = if ($obj.PSObject.Properties.Name -contains 'ctxPct') { $obj.ctxPct } else { $null }
$priorSrc = if ($obj.PSObject.Properties.Name -contains 'ctxPctSource') { $obj.ctxPctSource } else { $null }

Merge-TicketManifestFields -ManifestPath $manifestPath -Patch @{
    ctxPct       = (ConvertTo-PhaseObject -Existing $priorCtx -Name $Phase -Value $value)
    ctxPctSource = (ConvertTo-PhaseObject -Existing $priorSrc -Name $Phase -Value $source)
}
Write-Host "Wrote ctxPct.$Phase=$value ($source) on $manifestPath" -ForegroundColor Green
