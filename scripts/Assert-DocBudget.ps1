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
      rules/*.mdc        <=  60 lines  (already stubs)

    INDEX.md and human docs (USER-MANUAL.md, README.md, MACHINE-SETUP.md) are
    excluded — they grow with the workspace, not with individual tickets.

    Exit 0 = pass, 1 = at least one budget exceeded.

.PARAMETER Root
    Workspace root (the .cursor repo dir). Defaults to the parent of $PSScriptRoot.

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

# Budget rules: glob pattern → max lines. Order matters: first match wins.
$budgets = @(
    @{ Pattern = 'rules\*.mdc';              Budget = 60 }
    @{ Pattern = 'commands\*.md';            Budget = 40 }
    @{ Pattern = 'skills\workflow\*\SKILL.md'; Budget = 500 }
    @{ Pattern = 'skills\*\SKILL.md';        Budget = 500 }
    @{ Pattern = '_shared\*.md';             Budget = 150 }
    @{ Pattern = 'environments\*.md';        Budget = 120 }
    @{ Pattern = 'agents\*.md';              Budget = 150 }
)

# Docs excluded from budget checks (human docs, the catalog itself, this script's README)
$excluded = @(
    'INDEX.md', 'README.md', 'USER-MANUAL.md', 'MACHINE-SETUP.md', 'AGENTS.md', 'CLAUDE.md',
    'CUSTOMIZE.md', 'TEMPLATE.md',
    'AGENTS.md', 'plans\*.md', 'tmp\*', 'scripts\*', 'user\*', 'adapters\*',
    'environments\README.md', 'commands\README.md', 'scripts\README.md'
)

$violations = [System.Collections.Generic.List[object]]::new()
$checked    = 0

foreach ($rule in $budgets) {
    $glob = Join-Path $Root $rule.Pattern
    $files = @(Get-ChildItem -LiteralPath (Split-Path $glob -Parent) -Filter (Split-Path $glob -Leaf) `
                             -File -ErrorAction SilentlyContinue)

    foreach ($file in $files) {
        # Skip excluded docs
        $relative = $file.FullName.Substring($Root.Length).TrimStart('\', '/')
        $skip = $false
        foreach ($ex in $excluded) {
            if ($relative -like $ex) { $skip = $true; break }
        }
        if ($skip) { continue }

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
Write-Host "  Budgets: SKILL.md <=500, commands/*.md <=40, _shared/*.md <=150, environments/*.md <=120" -ForegroundColor DarkGray

if ($WarnOnly) { exit 0 }
exit 1
