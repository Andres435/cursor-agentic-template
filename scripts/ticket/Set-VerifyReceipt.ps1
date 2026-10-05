<#
.SYNOPSIS
    Record one repo's verify-repo result in plans/<ticket>-verify.json.

.DESCRIPTION
    /complete-task step 1 calls this once per verify-repo packet. The file is an
    array of packets, one per repo; calling again for the same repo replaces its
    packet. Assert-TicketArtifacts -Phase close requires a packet with boolean
    pass true for every local affected repo (spikes are exempt).

    pass is true only when tests passed (or were not run, with a reason) and
    Sonar did not report an error, and no failing test names were given.

.PARAMETER Ticket
    Work item, with or without the ticket prefix.

.PARAMETER Repo
    Repo name as it appears in the manifest's affectedRepos.

.PARAMETER Tests
    pass | fail | not-run, from the verify-repo packet.

.PARAMETER Sonar
    ok | error | not-run. Map the packet's skipped(...) to not-run.

.PARAMETER Failing
    Failing test or check names. Any entry makes pass false.

.PARAMETER Reason
    Required when -Tests is not-run (for example "docs-only change").

.PARAMETER RepoPath
    Repo working tree, to record the HEAD the result was taken at. Resolved
    through Resolve-TicketRoot when omitted.

.PARAMETER Root
    Override the workflow repo root (tests).

.EXAMPLE
    .\Set-VerifyReceipt.ps1 -Ticket TICKET-42 -Repo app -Tests pass -Sonar ok
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ticket,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][ValidateSet('pass', 'fail', 'not-run')][string]$Tests,
    [Parameter(Mandatory)][ValidateSet('ok', 'error', 'not-run')][string]$Sonar,
    [string[]]$Failing,
    [string]$Reason,
    [string]$RepoPath,
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path (Join-Path $PSScriptRoot 'lib') 'ManifestFields.ps1')

if ($Tests -eq 'not-run' -and [string]::IsNullOrWhiteSpace($Reason)) {
    throw "-Tests not-run needs -Reason (why no tests ran)."
}

$Key = Get-TicketKeyFromRaw -Ticket $Ticket
$RepoRoot = if ($Root) { $Root } else { Get-CursorRepoRoot -FromScriptRoot $PSScriptRoot }
$plansDir = Join-Path $RepoRoot 'plans'
if (-not (Test-Path -LiteralPath $plansDir)) { New-Item -ItemType Directory -Path $plansDir -Force | Out-Null }
$receiptPath = Join-Path $plansDir "$Key-verify.json"

if (-not $RepoPath -and -not $Root) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $resolvedJson = & (Join-Path $PSScriptRoot 'Resolve-TicketRoot.ps1') -Ticket $Key -Json 2>$null
        if ($LASTEXITCODE -eq 0 -and $resolvedJson) {
            $hit = @(($resolvedJson | ConvertFrom-Json).repos) | Where-Object { $_ -and $_.repo -eq $Repo } | Select-Object -First 1
            if ($hit -and $hit.path) { $RepoPath = [string]$hit.path }
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
}
$headSha = if ($RepoPath) { Get-GitHeadSha -RepoPath $RepoPath } else { $null }

$failingList = @($Failing | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$pass = ($Tests -ne 'fail') -and ($Sonar -ne 'error') -and ($failingList.Count -eq 0)

$packet = [pscustomobject]@{
    repo    = $Repo
    pass    = [bool]$pass
    tests   = $Tests
    sonar   = $Sonar
    failing = $failingList
    reason  = if ($Reason) { $Reason } else { $null }
    headSha = $headSha
    atUtc   = [DateTime]::UtcNow.ToString('o')
}

# Keep other repos' packets. A legacy single object without a repo is dropped: it cannot say
# which repo it covered.
$packets = New-Object System.Collections.Generic.List[object]
if (Test-Path -LiteralPath $receiptPath) {
    $doc = Get-Content -LiteralPath $receiptPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in @($doc)) {
        if (-not $p) { continue }
        if (-not ($p.PSObject.Properties.Name -contains 'repo') -or -not $p.repo) { continue }
        if ([string]$p.repo -eq $Repo) { continue }
        [void]$packets.Add($p)
    }
}
[void]$packets.Add($packet)

$json = ConvertTo-Json -InputObject @($packets.ToArray()) -Depth 10
[System.IO.File]::WriteAllText($receiptPath, $json + "`n", (New-Object System.Text.UTF8Encoding $false))
$color = if ($pass) { 'Green' } else { 'Yellow' }
Write-Host "Wrote verify receipt for $Repo (pass: $pass) on $receiptPath" -ForegroundColor $color
