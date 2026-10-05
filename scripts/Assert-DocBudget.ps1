<#
.SYNOPSIS
    Growth gate for workflow documentation. Fails when any doc file exceeds its
    soft line-count budget, printing the over-budget files and their budgets.

.DESCRIPTION
    This is a GROWTH gate, not a trim mandate. The instruction docs already sit at
    ~10% of the model window — well within budget. The gate exists to catch a
    single doc quietly ballooning to 800 lines across multiple PRs.

    Budgets (from the plan and 2026 agentic-workflow norms):
      SKILL.md           <= 500 lines
      commands/*.md      <=  40 lines  (shims only; body lives in skills/)
      _shared/*.md       <= 150 lines  (cross-phase contracts; phase-only docs live in skill references/)
      environments/*.md  <= 120 lines
      rules/*.mdc        <= 120 lines  (stub rules <= 60; triggered convention rules <= 120)
      adapters/claude/model-usage.md <= 70 lines (always-on import into every Claude session)

    INDEX.md and human docs (USER-MANUAL.md, README.md, MACHINE-SETUP.md) are
    excluded — they grow with the workspace, not with individual tickets.

    Exit 0 = pass, 1 = at least one budget exceeded.

.PARAMETER Root
    Workspace root (the workflow repo dir). Defaults to the parent of $PSScriptRoot.

.PARAMETER WarnOnly
    Print violations but exit 0 (advisory mode, suitable for CI comments).

.EXAMPLE
    .\scripts\Assert-DocBudget.ps1
    # Reports any over-budget docs and exits 1 if any found.

.EXAMPLE
    .\scripts\Assert-DocBudget.ps1 -WarnOnly
    # Advisory check — always exits 0.

.NOTES
    Part of the 2026 capability-oriented reorg.
    UTF-8 encoding note: read with -Encoding UTF8 to avoid ANSI mojibake on PS 5.1.
#>

[CmdletBinding()]
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent),
    [switch]$WarnOnly,
    # Print the always-loaded word count per IDE and the /start-ticket Load-map total.
    [switch]$Report
)

Set-StrictMode -Version Latest

# Budget rules: directory under Root + filter. Join-Path so Windows (work
# machine) and Linux (GitHub / some home machines) both resolve files.
$budgets = @(
    @{ RelDir = 'rules';        Filter = '*.mdc';    Recurse = $false; Budget = 120 }
    @{ RelDir = 'commands';     Filter = '*.md';     Recurse = $false; Budget = 40 }
    @{ RelDir = 'skills';       Filter = 'SKILL.md';    Recurse = $true;  Budget = 500 }
    @{ RelDir = 'skills';       Filter = '*.md';       Recurse = $true;  Budget = 500; PathLike = '*/playbooks/*' }
    @{ RelDir = '_shared';      Filter = '*.md';     Recurse = $false; Budget = 150 }
    @{ RelDir = 'environments'; Filter = '*.md';     Recurse = $false; Budget = 120 }
    @{ RelDir = 'agents';       Filter = '*.md';     Recurse = $false; Budget = 150 }
    # Single-file budget: this doc is `@`-imported into every Claude Code session
    # (see CLAUDE.md), unlike the rest of adapters/*, which the blanket 'adapters/*'
    # exclusion below still covers.
    @{ RelDir = 'adapters/claude'; Filter = 'model-usage.md'; Recurse = $false; Budget = 70 }
)

# Docs excluded from budget checks (human docs, the catalog itself, this script's README)
# Patterns use '/' — compared after normalizing '\' → '/' so Windows and Unix match.
# NOTE: 'adapters/*' would also swallow adapters/claude/model-usage.md (-like treats
# '*' as spanning '/', so it matches subdirectories too) — that file is carved out of
# the blanket adapters exclusion below so its dedicated budget rule above actually runs.
$excluded = @(
    'INDEX.md', 'README.md', 'USER-MANUAL.md', 'MACHINE-SETUP.md', 'AGENTS.md', 'CLAUDE.md',
    'CUSTOMIZE.md', 'TEMPLATE.md',
    'plans/*.md', 'tmp/*', 'scripts/*', 'user/*',
    'environments/README.md', 'commands/_README.md', 'scripts/README.md'
)
# adapters/* stays excluded for every file except the one with its own budget rule
# above -- keep this filter list separate from $excluded so a plain '-like' match
# can't accidentally swallow the single file we DO want checked.
$adaptersExcluded = @('adapters/*')
$adaptersBudgeted = @('adapters/claude/model-usage.md')

$violations = [System.Collections.Generic.List[object]]::new()
$checked    = 0

foreach ($rule in $budgets) {
    $dir = Join-Path $Root $rule.RelDir
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $gci = @{ LiteralPath = $dir; Filter = $rule.Filter; File = $true; ErrorAction = 'SilentlyContinue' }
    if ($rule.Recurse) { $gci['Recurse'] = $true }
    $files = @(Get-ChildItem @gci)

    foreach ($file in $files) {
        # Skip excluded docs
        $relative = ($file.FullName.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/')
        $skip = $false
        foreach ($ex in $excluded) {
            if ($relative -like $ex -or ([IO.Path]::GetFileName($relative) -eq $ex)) { $skip = $true; break }
        }
        if (-not $skip -and $adaptersBudgeted -notcontains $relative) {
            foreach ($ex in $adaptersExcluded) {
                if ($relative -like $ex) { $skip = $true; break }
            }
        }
        if ($skip) { continue }
        if ($rule.ContainsKey('PathLike') -and $relative -notlike $rule.PathLike) { continue }

        $lineCount = @(Get-Content -LiteralPath $file.FullName -Encoding UTF8 -ErrorAction SilentlyContinue).Count
        $checked++

        if ($lineCount -gt $rule.Budget) {
            $violations.Add([pscustomobject]@{
                File    = $relative
                Lines   = $lineCount
                Budget  = $rule.Budget
                Over    = $lineCount - $rule.Budget
            })
        }
    }
}

# ---- Word budgets: what a chat actually pays for, not how many lines a file has ----

function Get-WordCount([string]$Text) { return @($Text -split '\s+' | Where-Object { $_ }).Count }

# GitHub heading slug: lower case, punctuation dropped (except - and _), spaces to '-'.
function Get-HeadingSlug([string]$Heading) {
    return (($Heading.Trim().ToLowerInvariant() -replace '[^\p{L}\p{N} _-]', '') -replace ' ', '-')
}

# Words in a file, or only in the section under #anchor (until the next heading of the same or a
# higher level). $null when the file or the anchor is missing.
function Get-DocWords([string]$Path, [string]$Anchor) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
    if (-not $Anchor) { return (Get-WordCount ($lines -join "`n")) }
    # A '#' line inside a ``` fence is code (a PowerShell comment), not a heading.
    $inFence = $false
    $isHeading = @(foreach ($l in $lines) {
        if ($l -match '^\s*```') { $inFence = -not $inFence; $false; continue }
        (-not $inFence) -and ($l -match '^#{1,6}\s')
    })
    $start = -1; $level = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($isHeading[$i] -and $lines[$i] -match '^(#{1,6})\s+(.+?)\s*#*\s*$' -and (Get-HeadingSlug $Matches[2]) -eq $Anchor) {
            $start = $i; $level = $Matches[1].Length; break
        }
    }
    if ($start -lt 0) { return $null }
    $end = $lines.Count
    for ($j = $start + 1; $j -lt $lines.Count; $j++) {
        if ($isHeading[$j] -and $lines[$j] -match '^(#{1,6})\s' -and $Matches[1].Length -le $level) { $end = $j; break }
    }
    return (Get-WordCount ($lines[$start..($end - 1)] -join "`n"))
}

# 1. Always-loaded set per IDE: every word here is paid by every chat.
# Claude Code: the workspace CLAUDE.md (this repo's root CLAUDE.md, or the adapter template that
# is written next to the clones) plus each `@import` it names, `{{folder}}/` stripped.
$alwaysCap = 1500
$alwaysSets = [ordered]@{}
$claudeEntry = if (Test-Path -LiteralPath (Join-Path $Root 'CLAUDE.md')) { 'CLAUDE.md' } else { 'adapters/claude/workspace-CLAUDE.md' }
$claudeFiles = @($claudeEntry) + @(Get-Content -LiteralPath (Join-Path $Root $claudeEntry) -Encoding UTF8 -ErrorAction SilentlyContinue |
    Where-Object { $_ -match '^@(\S+)' } | ForEach-Object { $Matches[1] -replace '^\{\{folder\}\}/', '' })
$alwaysSets['Claude Code'] = $claudeFiles
$cursorRules = @(Get-ChildItem -LiteralPath (Join-Path $Root 'rules') -Filter '*.mdc' -File -ErrorAction SilentlyContinue |
    Where-Object { (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) -match '(?m)^alwaysApply:\s*true' } |
    ForEach-Object { "rules/$($_.Name)" })
$alwaysSets['Cursor'] = @('AGENTS.md') + $cursorRules
$alwaysSets['Codex'] = @('AGENTS.md')
$alwaysReport = [System.Collections.Generic.List[string]]::new()
foreach ($ide in $alwaysSets.Keys) {
    $total = 0
    foreach ($rel in $alwaysSets[$ide]) {
        $w = Get-DocWords (Join-Path $Root $rel) $null
        if ($null -ne $w) { $total += $w }
    }
    $checked++
    $alwaysReport.Add(("{0,-12} {1,5} words  ({2})" -f $ide, $total, ($alwaysSets[$ide] -join ', ')))
    if ($total -gt $alwaysCap) {
        $violations.Add([pscustomobject]@{ File = "always-loaded set ($ide)"; Lines = $total; Budget = $alwaysCap; Over = $total - $alwaysCap; Unit = 'words' })
    }
}

# 2. Skill references: loaded whole unless the doc offers slices.
$refCap = 1500
$refAllowlist = @()  # a reference that is loaded by section may be listed here instead of adding '## Slices'
foreach ($ref in @(Get-ChildItem -LiteralPath (Join-Path $Root 'skills') -Filter '*.md' -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { ($_.FullName -replace '\\', '/') -like '*/references/*' })) {
    $relative = ($ref.FullName.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/')
    if ($refAllowlist -contains $relative) { continue }
    $text = Get-Content -LiteralPath $ref.FullName -Raw -Encoding UTF8
    if ($text -match '(?m)^## Slices') { continue }
    $checked++
    $w = Get-WordCount $text
    if ($w -gt $refCap) {
        $violations.Add([pscustomobject]@{ File = $relative; Lines = $w; Budget = $refCap; Over = $w - $refCap; Unit = 'words' })
    }
}

# 3. /start-ticket before plan approval: the skill, its playbook, and every `always` Load-map row.
$startCap = 7000
$playbook = Join-Path $Root 'skills/start-ticket/playbooks/start-ticket.md'
$startTotal = $null
$startRows = [System.Collections.Generic.List[string]]::new()
if (Test-Path -LiteralPath $playbook) {
    $startTotal = (Get-DocWords (Join-Path $Root 'skills/start-ticket/SKILL.md') $null) + (Get-DocWords $playbook $null)
    $inMap = $false
    foreach ($line in (Get-Content -LiteralPath $playbook -Encoding UTF8)) {
        if ($line -match '^## Load map') { $inMap = $true; continue }
        if ($inMap -and $line -match '^## ') { break }
        if (-not $inMap -or $line -notmatch '^\|\s*\[[^\]]*\]\(([^)#]+)(?:#([^)]+))?\)\s*\|\s*([^|]+?)\s*\|') { continue }
        $relPath = $Matches[1]
        $target = Join-Path (Split-Path $playbook -Parent) $relPath
        $anchor = if ($Matches.Count -gt 2) { $Matches[2] } else { $null }
        $when = $Matches[3]
        $w = Get-DocWords $target $anchor
        if ($null -eq $w) {
            $violations.Add([pscustomobject]@{ File = "start-ticket Load map: $relPath#$anchor"; Lines = 0; Budget = 0; Over = 0; Unit = 'missing file or anchor' })
            continue
        }
        $startRows.Add(("  {0,-10} {1,5}  {2}{3}" -f $when, $w, $relPath, $(if ($anchor) { "#$anchor" } else { '' })))
        if ($when -eq 'always') { $startTotal += $w }
    }
    $checked++
    if ($startTotal -gt $startCap) {
        $violations.Add([pscustomobject]@{ File = 'start-ticket chat before plan approval'; Lines = $startTotal; Budget = $startCap; Over = $startTotal - $startCap; Unit = 'words' })
    }
}

if ($Report) {
    Write-Host "Always-loaded words per IDE (cap $alwaysCap):"
    $alwaysReport | ForEach-Object { Write-Host "  $_" }
    if ($null -ne $startTotal) {
        Write-Host "start-ticket before plan approval: $startTotal words (cap $startCap; skill + playbook + 'always' rows)"
        $startRows | ForEach-Object { Write-Host $_ }
    }
}

if ($violations.Count -eq 0) {
    Write-Host "[PASS] Doc budget: $checked file(s) checked, all within budget." -ForegroundColor Green
    exit 0
}

$label = if ($WarnOnly) { "[WARN]" } else { "[FAIL]" }
$color = if ($WarnOnly) { "Yellow" } else { "Red" }
Write-Host "$label Doc budget: $($violations.Count) file(s) over budget (of $checked checked):" -ForegroundColor $color
foreach ($v in ($violations | Sort-Object Over -Descending)) {
    $unit = if ($v.PSObject.Properties.Name -contains 'Unit') { $v.Unit } else { 'lines' }
    Write-Host ("  {0,-60} {1,5} {2}  (budget {3}, over by {4})" -f $v.File, $v.Lines, $unit, $v.Budget, $v.Over) -ForegroundColor $color
}
Write-Host "  Move over-budget detail to skill references/ or split into slices." -ForegroundColor DarkGray
Write-Host "  Budgets: SKILL.md <=500, commands/*.md <=40, _shared/*.md <=150, environments/*.md <=120, rules/*.mdc <=120, adapters/claude/model-usage.md <=70 lines;" -ForegroundColor DarkGray
Write-Host "  always-loaded set <=$alwaysCap words per IDE, skills/*/references <=$refCap words (unless sliced), start-ticket before approval <=$startCap words" -ForegroundColor DarkGray

if ($WarnOnly) { exit 0 }
exit 1
