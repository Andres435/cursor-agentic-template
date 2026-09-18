<#
.SYNOPSIS
    Append or update one ticket's row in plans/ticket-ledger.md and recompute the
    summary block.

.DESCRIPTION
    The ledger replaces per-ticket plans/WI<n>-closeout.md files. Those were
    2-6 KB each, 29 of them, and nothing read them back except the old
    Update-ScorecardTrend.ps1 -- the durable value was always the one-line
    scorecard plus the lesson row in plans/closeout-index.md.

    /complete-task calls this script instead of hand-writing a markdown table, so
    the row format cannot drift. A full WI<n>-closeout.md is written only when a
    retrospective actually earns a page (see _shared/task-retrospective.md).

    Re-running for the same ticket REPLACES that ticket's row, so a reopen/reclose
    updates in place rather than duplicating.

.PARAMETER Ticket
    Work item, with or without the WI prefix.

.PARAMETER Type
    bug | feature | spike | refactor.

.PARAMETER Closed
    Close date (yyyy-MM-dd). Defaults to today.

.PARAMETER Mode
    branch | worktree. Defaults to whatever Resolve-TicketRoot.ps1 reports.

.PARAMETER Hours
    Calculated session hours (see _shared/session-time-tracking.md).

.PARAMETER Points
    Story points written to ADO Custom.StoryPointsActual.

.PARAMETER Efficiency
.PARAMETER Contextualization
.PARAMETER CostTokens
    Session scorecard axes, 1-5 (5 = excellent). Omit for n/a.

.PARAMETER ContextPct
    Occupancy of the /complete-task chat (ledger Ctx%).

.PARAMETER ContextPctStart
    Occupancy of the /start-ticket chat (ledger CtxS%). Copied from the manifest
    ctxPct.start when omitted.

.PARAMETER ContextPctReview
    Occupancy of the /review-changes chat (ledger CtxR%). Copied from the
    manifest ctxPct.review when omitted.

.PARAMETER Pr
    PR number or URL, if one was created.

.PARAMETER Root
    Override the .cursor repo root (tests).

.PARAMETER Rewrite
    Re-read the ledger, migrate old 11-column rows, and write the current header
    without changing any ticket's values.

.PARAMETER Remove
    Delete this ticket's row. For a row entered by mistake -- the file itself must
    never be hand-edited, so removal has to be a switch, not a manual delete.

.PARAMETER SeedFromCloseouts
    One-time migration: build the ledger from every existing WI*-closeout.md
    (front matter + scorecard) instead of from the parameters above. Additive:
    it replaces rows for tickets it finds and leaves every other row alone, so it
    can never destroy a row whose closeout file is gone.

.EXAMPLE
    .\Update-TicketLedger.ps1 -Ticket WI22132 -Type feature -Hours 6 -Points 3 -Efficiency 4 -Contextualization 4 -CostTokens 3 -ContextPct 78

.EXAMPLE
    .\Update-TicketLedger.ps1 -SeedFromCloseouts

.NOTES
    Durable lessons go to plans/closeout-index.md, not here.
#>

[CmdletBinding(DefaultParameterSetName = 'Row')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Row')]
    [string]$Ticket,

    [Parameter(ParameterSetName = 'Row')]
    [ValidateSet('bug', 'feature', 'spike', 'refactor')]
    [string]$Type,

    [Parameter(ParameterSetName = 'Row')]
    [string]$Closed,

    [Parameter(ParameterSetName = 'Row')]
    [ValidateSet('branch', 'worktree')]
    [string]$Mode,

    [Parameter(ParameterSetName = 'Row')]
    [string]$Hours,

    [Parameter(ParameterSetName = 'Row')]
    [string]$Points,

    [Parameter(ParameterSetName = 'Row')]
    [ValidateRange(1, 5)]
    [int]$Efficiency,

    [Parameter(ParameterSetName = 'Row')]
    [ValidateRange(1, 5)]
    [int]$Contextualization,

    [Parameter(ParameterSetName = 'Row')]
    [ValidateRange(1, 5)]
    [int]$CostTokens,

    [Parameter(ParameterSetName = 'Row')]
    [ValidateRange(0, 100)]
    [int]$ContextPct,

    [Parameter(ParameterSetName = 'Row')]
    [ValidateRange(0, 100)]
    [int]$ContextPctStart,

    [Parameter(ParameterSetName = 'Row')]
    [ValidateRange(0, 100)]
    [int]$ContextPctReview,

    [Parameter(ParameterSetName = 'Row')]
    [string]$Pr,

    [Parameter(ParameterSetName = 'Row')]
    [switch]$Remove,

    [string]$Root,

    [Parameter(ParameterSetName = 'Rewrite')]
    [switch]$Rewrite,

    [Parameter(Mandatory, ParameterSetName = 'Seed')]
    [switch]$SeedFromCloseouts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Read ticket prefix from profile.json (default 'WI' for TMO).
function Get-TicketPrefix {
    $p = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'profile.json'
    if (Test-Path -LiteralPath $p) {
        try { $c = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
              if ($c.ticketPrefix) { return [string]$c.ticketPrefix } } catch { }
    }
    return 'WI'
}
$TICKET_PREFIX = Get-TicketPrefix
$TICKET_ROW_PATTERN = "^\|\s*$([regex]::Escape($TICKET_PREFIX))\d+"

$RepoRoot = if ($Root) { $Root } else { Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
$PlansDir = Join-Path $RepoRoot 'plans'
$OutPath  = Join-Path $PlansDir 'ticket-ledger.md'

$Columns = @('Ticket', 'Type', 'Closed', 'Mode', 'Hours', 'Pts', 'E', 'C', '$tok', 'CtxS%', 'CtxR%', 'Ctx%', 'PR')

function New-LedgerRow {
    param([string]$Ticket, [string]$Type, [string]$Closed, [string]$Mode,
          [string]$Hours, [string]$Pts, [string]$E, [string]$C, [string]$Tok,
          [string]$CtxS, [string]$CtxR, [string]$Ctx, [string]$Pr)
    [pscustomobject]@{
        Ticket = $Ticket
        Type   = $Type
        Closed = $Closed
        Mode   = $Mode
        Hours  = $Hours
        Pts    = $Pts
        E      = $E
        C      = $C
        Tok    = $Tok
        CtxS   = $CtxS
        CtxR   = $CtxR
        Ctx    = $Ctx
        PR     = $Pr
    }
}

function Convert-LedgerCells {
    param([string[]]$Cells)
    $c = @($Cells)
    # Legacy 11-col: Ticket..$tok, Ctx%, PR → insert empty CtxS% CtxR% before Ctx%.
    if ($c.Count -eq 11) {
        $c = @($c[0..8]) + @('', '') + @($c[9], $c[10])
    }
    elseif ($c.Count -lt $Columns.Count) {
        $c = @($c) + @('') * ($Columns.Count - $c.Count)
    }
    return ,$c
}

function Get-Blank {
    param($Value)
    if ($null -eq $Value) { return '' }
    $s = [string]$Value
    if ([string]::IsNullOrWhiteSpace($s)) { return '' }
    # A markdown pipe inside a cell would break the table.
    return ($s -replace '\|', '\')
}

function Get-ManifestCtx {
    param([string]$TicketKey, [string]$Phase)
    $mfPath = Join-Path $PlansDir "$TicketKey-manifest.json"
    if (-not (Test-Path -LiteralPath $mfPath)) { return $null }
    try {
        $mf = Get-Content -LiteralPath $mfPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $mf) { return $null }
        if (-not ($mf.PSObject.Properties.Name -contains 'ctxPct')) { return $null }
        $ctx = $mf.ctxPct
        if (-not $ctx) { return $null }
        if (-not ($ctx.PSObject.Properties.Name -contains $Phase)) { return $null }
        $v = $ctx.$Phase
        if ($null -eq $v -or [string]::IsNullOrWhiteSpace([string]$v)) { return $null }
        return [int]$v
    } catch {
        return $null
    }
}

# ---------------------------------------------------------------- read existing
$rows = [System.Collections.Generic.List[object]]::new()

if (Test-Path -LiteralPath $OutPath) {
    # Read as UTF-8 explicitly. PowerShell 5.1's Get-Content defaults to the ANSI
    # codepage for BOM-less files, which silently mangles any non-ASCII cell
    # (em-dash, accented name) into mojibake on the next write-back.
    foreach ($line in (Get-Content -LiteralPath $OutPath -Encoding UTF8)) {
        if ($line -notmatch $TICKET_ROW_PATTERN) { continue }
        $cells = @(($line.Trim() -replace '^\|', '' -replace '\|$', '') -split '\|' | ForEach-Object { $_.Trim() })
        $cells = Convert-LedgerCells -Cells $cells
        $rows.Add((New-LedgerRow -Ticket $cells[0] -Type $cells[1] -Closed $cells[2] -Mode $cells[3] `
            -Hours $cells[4] -Pts $cells[5] -E $cells[6] -C $cells[7] -Tok $cells[8] `
            -CtxS $cells[9] -CtxR $cells[10] -Ctx $cells[11] -Pr $cells[12]))
    }
}

# ------------------------------------------------------------------ build a row
if ($SeedFromCloseouts) {
    function Get-ScoreFromText {
        param([string]$Text, [string]$Axis)
        $esc = [regex]::Escape($Axis)
        # Bullet form: "Efficiency (1-5): 3"
        $m = [regex]::Match($Text, "$esc\s*\(1.5\):\s*(\d)")
        if ($m.Success) { return $m.Groups[1].Value }
        # Table form: "| Efficiency | 4 |"
        $m = [regex]::Match($Text, "(?m)^\|\s*$esc\s*\|\s*(\d)\s*\|")
        if ($m.Success) { return $m.Groups[1].Value }
        return ''
    }

    $seeded = 0
    foreach ($file in (Get-ChildItem -Path $PlansDir -Filter 'WI*-closeout.md' -ErrorAction SilentlyContinue)) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        $key = if ($text -match '(?m)^ticket:\s*(WI\d+)') { $Matches[1] }
               elseif ($file.BaseName -match '^(WI\d+)') { $Matches[1] }
               else { continue }
        $cl = ''
        if ($text -match '(?m)^closed:\s*(\d{4}-\d{2}-\d{2})') { $cl = $Matches[1] }
        $ty = ''
        if ($text -match '(?m)^type:\s*(\w+)') { $ty = $Matches[1] }

        $e = Get-ScoreFromText $text 'Efficiency'
        $c = Get-ScoreFromText $text 'Contextualization'
        $k = Get-ScoreFromText $text 'Cost / tokens'
        if (-not $k) { $k = Get-ScoreFromText $text 'Cost/tokens' }

        # Every seeded ticket predates branch mode.
        $existing = $rows | Where-Object { $_.Ticket -eq $key } | Select-Object -First 1
        if ($existing) { [void]$rows.Remove($existing) }
        $rows.Add((New-LedgerRow -Ticket $key -Type $ty -Closed $cl -Mode 'worktree' `
            -Hours '' -Pts '' -E $e -C $c -Tok $k -CtxS '' -CtxR '' -Ctx '' -Pr ''))
        $seeded++
    }
    Write-Host "Seeded $seeded row(s) from WI*-closeout.md." -ForegroundColor Cyan
}
elseif (-not $Rewrite) {
    $digits = $Ticket -replace '[^\d]', ''
    if (-not $digits) { throw "Could not read a work item number from '$Ticket'." }
    $key = $TICKET_PREFIX + $digits

    if ($Remove) {
        $gone = @($rows | Where-Object { $_.Ticket -eq $key })
        if (-not $gone.Count) { throw "No row for $key in $OutPath -- nothing to remove." }
        foreach ($r in $gone) { [void]$rows.Remove($r) }
        Write-Host "Removed $($gone.Count) row(s) for $key." -ForegroundColor Yellow
    }
    else {

    $closedDate = Get-Blank $Closed
    if (-not $closedDate) { $closedDate = Get-Date -Format 'yyyy-MM-dd' }

    $resolvedMode = Get-Blank $Mode
    if (-not $resolvedMode) {
        # Fall back to the live answer so the row records what actually ran.
        try {
            $probe = & (Join-Path $PSScriptRoot 'Resolve-TicketRoot.ps1') -Ticket $key -Json 2>$null | ConvertFrom-Json
            if ($probe -and $probe.mode) { $resolvedMode = $probe.mode }
        }
        catch {
            $resolvedMode = ''
        }
    }

    $existing = $rows | Where-Object { $_.Ticket -eq $key } | Select-Object -First 1
    if ($existing) {
        Write-Host "Replacing existing row for $key." -ForegroundColor DarkGray
        [void]$rows.Remove($existing)
    }

    $ctxClose = if ($PSBoundParameters.ContainsKey('ContextPct')) { $ContextPct } else { $null }
    $ctxS = if ($PSBoundParameters.ContainsKey('ContextPctStart')) { $ContextPctStart } else { Get-ManifestCtx -TicketKey $key -Phase 'start' }
    $ctxR = if ($PSBoundParameters.ContainsKey('ContextPctReview')) { $ContextPctReview } else { Get-ManifestCtx -TicketKey $key -Phase 'review' }

    $rows.Add((New-LedgerRow -Ticket $key -Type (Get-Blank $Type) -Closed $closedDate `
        -Mode $resolvedMode -Hours (Get-Blank $Hours) -Pts (Get-Blank $Points) `
        -E (Get-Blank $(if ($PSBoundParameters.ContainsKey('Efficiency')) { $Efficiency } else { $null })) `
        -C (Get-Blank $(if ($PSBoundParameters.ContainsKey('Contextualization')) { $Contextualization } else { $null })) `
        -Tok (Get-Blank $(if ($PSBoundParameters.ContainsKey('CostTokens')) { $CostTokens } else { $null })) `
        -CtxS (Get-Blank $ctxS) -CtxR (Get-Blank $ctxR) `
        -Ctx (Get-Blank $ctxClose) `
        -Pr (Get-Blank $Pr)))
    }
}

# ------------------------------------------------------------------ recalculate
function Measure-Axis {
    param([string]$Property)
    $vals = @($rows | ForEach-Object { $_.$Property } | Where-Object { $_ -match '^\d$' } | ForEach-Object { [int]$_ })
    if (-not $vals.Count) { return 'n/a' }
    return [math]::Round((($vals | Measure-Object -Average).Average), 1)
}

function Measure-Ctx {
    param([string]$Property)
    $vals = @($rows | ForEach-Object { $_.$Property } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
    if (-not $vals.Count) { return 'n/a' }
    return [string]([math]::Round((($vals | Measure-Object -Average).Average), 0)) + '%'
}

$scoredCount = @($rows | Where-Object { $_.E -match '^\d$' }).Count
$avgCtxS = Measure-Ctx 'CtxS'
$avgCtxR = Measure-Ctx 'CtxR'
$avgCtx  = Measure-Ctx 'Ctx'

$sorted = $rows | Sort-Object @{ Expression = { if ($_.Closed) { $_.Closed } else { '0000-00-00' } } }, Ticket

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# Ticket ledger')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('One row per closed ticket. Written by `scripts/Update-TicketLedger.ps1` at')
[void]$sb.AppendLine('`/complete-task` -- do not hand-edit, the script owns this format.')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('This replaces the per-ticket `WI<n>-closeout.md` files. Durable *lessons* live in')
[void]$sb.AppendLine('[closeout-index.md](closeout-index.md); a full closeout page is written only when a')
[void]$sb.AppendLine('retrospective earns one. Scorecard scale 1-5 (5 = excellent). `CtxS%` is the')
[void]$sb.AppendLine('/start-ticket chat, `CtxR%` is `/review-changes`, `Ctx%` is `/complete-task`.')
[void]$sb.AppendLine('`/implement` is not recorded. Do not backfill old rows.')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| Tickets | Scored | Avg E | Avg C | Avg $tok | Avg CtxS% | Avg CtxR% | Avg Ctx% |')
[void]$sb.AppendLine('|---|---|---|---|---|---|---|---|')
[void]$sb.AppendLine("| $($rows.Count) | $scoredCount | $(Measure-Axis 'E') | $(Measure-Axis 'C') | $(Measure-Axis 'Tok') | $avgCtxS | $avgCtxR | $avgCtx |")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| ' + ($Columns -join ' | ') + ' |')
[void]$sb.AppendLine('|' + ('---|' * $Columns.Count))
foreach ($r in $sorted) {
    [void]$sb.AppendLine("| $($r.Ticket) | $($r.Type) | $($r.Closed) | $($r.Mode) | $($r.Hours) | $($r.Pts) | $($r.E) | $($r.C) | $($r.Tok) | $($r.CtxS) | $($r.CtxR) | $($r.Ctx) | $($r.PR) |")
}

# UTF-8 with NO BOM. Set-Content -Encoding utf8 on PS 5.1 emits a BOM, which then
# leaks into every diff of this file and confuses tools that expect plain markdown.
[System.IO.File]::WriteAllText($OutPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Wrote $OutPath ($($rows.Count) ticket(s), $scoredCount scored)." -ForegroundColor Green
