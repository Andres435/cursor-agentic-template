#Requires -Version 7
<#
.SYNOPSIS
    Read stackSmoke and report Never tested / Tested / Untested latest.

.DESCRIPTION
    Absence is Never tested. A passed/failed stamp whose work-diff fingerprint
    no longer matches is Untested latest changes (stale), even if status was
    not rewritten yet.

.PARAMETER Ticket
    Work item, with or without the ticket prefix.

.PARAMETER Json
    Emit { ticket, recorded, effective, reason, label, lastStatus }.

.PARAMETER RepoPaths
    JSON object mapping repo name to working-tree path. Overrides Resolve-TicketRoot.

.PARAMETER Root
    Override the workflow repo root (tests).

.EXAMPLE
    .\Get-StackSmoke.ps1 -Ticket TICKET-42 -Json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ticket,
    [switch]$Json,
    [string]$RepoPaths,
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path (Join-Path $PSScriptRoot 'lib') 'ManifestFields.ps1')

$Key = Get-TicketKeyFromRaw -Ticket $Ticket
$RepoRoot = if ($Root) { $Root } else { Get-CursorRepoRoot -FromScriptRoot $PSScriptRoot }
$manifestPath = Get-TicketManifestFile -RepoRoot $RepoRoot -TicketKey $Key

$stamp = $null
if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.PSObject.Properties.Name -contains 'stackSmoke') {
        $stamp = $manifest.stackSmoke
    }
}

$pathMap = @{}
if ($RepoPaths) {
    foreach ($p in ($RepoPaths | ConvertFrom-Json).PSObject.Properties) { $pathMap[$p.Name] = [string]$p.Value }
}
if (-not $pathMap.Count) {
    $resolveScript = Join-Path $PSScriptRoot 'Resolve-TicketRoot.ps1'
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $resolvedJson = & $resolveScript -Ticket $Key -Json 2>$null
        if ($LASTEXITCODE -eq 0 -and $resolvedJson) {
            $resolved = $resolvedJson | ConvertFrom-Json
            if ($resolved.repos) {
                foreach ($r in @($resolved.repos)) {
                    if ($r.repo -and $r.path) { $pathMap[[string]$r.repo] = [string]$r.path }
                }
            }
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

$d = Get-StackSmokeDecision -Stamp $stamp -RepoPaths $pathMap
$result = [pscustomobject]@{
    ticket     = $Key
    recorded   = $d.recorded
    effective  = $d.effective
    reason     = $d.reason
    label      = $d.label
    lastStatus = $(if ($d.PSObject.Properties.Name -contains 'lastStatus') { $d.lastStatus } else { $null })
}

if ($Json) {
    $result | ConvertTo-Json -Depth 4
    exit 0
}

Write-Host ("{0}: stack smoke {1} ({2})" -f $Key, $d.label, $d.reason)
exit 0
