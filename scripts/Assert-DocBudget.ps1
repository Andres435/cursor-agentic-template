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
    [switch]$WarnOnly
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

if ($violations.Count -eq 0) {
    Write-Host "[PASS] Doc budget: $checked file(s) checked, all within budget." -ForegroundColor Green
    exit 0
}

$label = if ($WarnOnly) { "[WARN]" } else { "[FAIL]" }
$color = if ($WarnOnly) { "Yellow" } else { "Red" }
Write-Host "$label Doc budget: $($violations.Count) file(s) over budget (of $checked checked):" -ForegroundColor $color
foreach ($v in ($violations | Sort-Object Over -Descending)) {
    Write-Host ("  {0,-60} {1,4} lines  (budget {2}, over by {3})" -f $v.File, $v.Lines, $v.Budget, $v.Over) -ForegroundColor $color
}
Write-Host "  Move over-budget detail to skill references/ or split into slices." -ForegroundColor DarkGray
Write-Host "  Budgets: SKILL.md <=500, commands/*.md <=40, _shared/*.md <=150, environments/*.md <=120, rules/*.mdc <=120, adapters/claude/model-usage.md <=70" -ForegroundColor DarkGray

if ($WarnOnly) { exit 0 }
exit 1
