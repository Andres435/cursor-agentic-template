#Requires -Version 7
<#
.SYNOPSIS
    The work-item prefix for this profile (profile.json ticketPrefix; "TICKET-" when unset).
    Dot-sourced by ManifestFields.ps1, Assert-TicketArtifacts, Update-TicketLedger,
    Search-CloseoutMemory, and Assert-AgenticFlow so every ticket script reads one prefix.
    Do not run directly.
#>

Set-StrictMode -Version Latest

# The repo root as seen from this file: lib -> ticket -> scripts -> root.
$TicketPrefixRepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent

function Get-TicketPrefix {
    param([string]$Root = $TicketPrefixRepoRoot)
    $p = Join-Path $Root 'profile.json'
    if (Test-Path -LiteralPath $p) {
        try {
            $c = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
            if (($c.PSObject.Properties.Name -contains 'ticketPrefix') -and $c.ticketPrefix) { return [string]$c.ticketPrefix }
        } catch { }
    }
    return 'TICKET-'
}
