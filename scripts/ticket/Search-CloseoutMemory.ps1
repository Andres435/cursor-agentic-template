<#
.SYNOPSIS
    Search prior ticket memory for compact lessons matching this ticket.

.DESCRIPTION
    Used by ticket-router at /start-ticket. Reads plans/closeout-index.md -- the one
    retrieval surface, one dense row per durable lesson. Prints JSON:
    [{ ticket, lesson }, ...] (max 8). Never reads or dumps whole closeout files.

.PARAMETER Query
    Free-text keywords from the work-item title / area.

.PARAMETER Repos
    Affected repo names (comma-separated or array).

.PARAMETER Integration
    OSC, Miniter, TaxTracking, or empty.

.PARAMETER MaxResults
    Cap (default 8).

.EXAMPLE
    .\Search-CloseoutMemory.ps1 -Query "OSC document download" -Repos TmoPro -Integration OSC
#>

[CmdletBinding()]
param(
    [string]$Query = '',
    [string[]]$Repos = @(),
    [string]$Integration = '',
    [int]$MaxResults = 8
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$PlansDir = Join-Path $RepoRoot 'plans'
$IndexPath = Join-Path $PlansDir 'closeout-index.md'

if ($Repos.Count -eq 1 -and $Repos[0] -match ',') {
    $Repos = @($Repos[0] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

$terms = [System.Collections.Generic.List[string]]::new()
foreach ($piece in @($Query, $Integration) + @($Repos)) {
    if ([string]::IsNullOrWhiteSpace($piece)) { continue }
    foreach ($tok in ($piece -split '[^\w]+')) {
        if ($tok.Length -ge 3) { [void]$terms.Add($tok.ToLowerInvariant()) }
    }
}
$terms = @($terms | Select-Object -Unique)
if ($terms.Count -eq 0) {
    '[]'
    return
}

function Get-TermScore {
    param([string]$Text)
    $lower = $Text.ToLowerInvariant()
    $n = 0
    foreach ($t in $terms) {
        if ($lower.Contains($t)) { $n++ }
    }
    return $n
}

$hits = @()

if (Test-Path $IndexPath) {
    Get-Content -Path $IndexPath | ForEach-Object {
        if ($_ -notmatch '^\|\s*(WI\d+)') { return }
        $score = Get-TermScore $_
        if ($score -le 0) { return }
        $cols = $_.Trim().Trim('|') -split '\|' | ForEach-Object { $_.Trim() }
        if ($cols.Count -lt 3) { return }
        $hits += [pscustomobject]@{
            Ticket = $cols[0]
            Lesson = $cols[2]
            Score  = $score
        }
    }
}

# There is deliberately no fall-through to plans/WI*-closeout.md. Those files are
# now written only for the rare ticket whose retrospective earned a page, and that
# ticket's lesson is already an index row -- scanning them would re-read whole
# files to rediscover a line that is one grep away. Returning fewer, better rows is
# the correct outcome; the index is the retrieval surface (see _shared/closeout-search.md).

$result = @(
    $hits |
        Sort-Object Score -Descending |
        Select-Object -First $MaxResults |
        ForEach-Object {
            [ordered]@{ ticket = $_.Ticket; lesson = $_.Lesson }
        }
)

if ($result.Count -eq 0) {
    '[]'
} else {
    $json = $result | ConvertTo-Json -Compress
    if ($result.Count -eq 1 -and $json -notmatch '^\s*\[') { "[$json]" } else { $json }
}
