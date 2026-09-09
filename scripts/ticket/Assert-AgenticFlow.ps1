<#
.SYNOPSIS
    Fail-closed gate for all agentic-flow requirements.

.DESCRIPTION
    Encodes the current workflow contracts from README.md, _shared/ticket-artifacts.md,
    and _shared/severity-and-output.md as mechanical checks. Run before merging any PR
    that touches workflow docs, scripts, or CI config.

    Wave 2's /doctor calls this same script so local and CI cannot drift.

    Exit code 0 = all checks pass, 1 = at least one violation.

.PARAMETER Root
    Workspace root. Defaults to two levels up from $PSScriptRoot (scripts/ticket/).

.PARAMETER WarnOnly
    Print violations but exit 0.

.EXAMPLE
    .\scripts\ticket\Assert-AgenticFlow.ps1

.EXAMPLE
    .\scripts\ticket\Assert-AgenticFlow.ps1 -WarnOnly
#>

[CmdletBinding()]
param(
    [string]$Root = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [switch]$WarnOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$violations = [System.Collections.Generic.List[string]]::new()
function Fail { param([string]$Msg) $violations.Add($Msg) }

# Child scripts call `exit`, so they must run in a subprocess. Reuse *this*
# process's executable: Windows work machines are powershell.exe (5.1);
# GitHub ubuntu and some home machines are pwsh. Do not hardcode either name.
function Get-CurrentPowerShellHost {
    try {
        $path = (Get-Process -Id $PID).Path
        if ($path -and (Test-Path -LiteralPath $path)) { return $path }
    } catch { }
    $onWindows = [System.Environment]::OSVersion.Platform -eq 'Win32NT'
    $names = if ($onWindows) { @('powershell.exe', 'powershell', 'pwsh') } else { @('pwsh') }
    foreach ($name in $names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { return $cmd.Source }
    }
    throw "No PowerShell host found."
}

# ---- 1. Doc budgets --------------------------------------------------------
# Delegate to Assert-DocBudget.ps1 so the budget table is single-source.
$budgetScript = Join-Path $Root 'scripts' 'Assert-DocBudget.ps1'
if (Test-Path -LiteralPath $budgetScript) {
    $out = & (Get-CurrentPowerShellHost) -NonInteractive -NoProfile -File $budgetScript -Root $Root 2>&1
    if ($LASTEXITCODE -ne 0) {
        foreach ($line in $out) {
            if ($line -match 'over by') { Fail "doc-budget: $line" }
        }
        if (-not ($violations | Where-Object { $_ -like 'doc-budget:*' })) {
            Fail "doc-budget: Assert-DocBudget.ps1 exited $LASTEXITCODE -- $($out -join '; ')"
        }
    }
} else {
    Fail "doc-budget: Assert-DocBudget.ps1 not found at $budgetScript"
}

# ---- 2. Command shims must reference skills/, adapters/, or scripts/ ------
# A command is a thin shim: its body lives in skills/, adapters/, or scripts/.
# Fail only when none of those patterns appear (guards against full skill bodies
# accidentally committed as commands).
$commandsDir = Join-Path $Root 'commands'
if (Test-Path -LiteralPath $commandsDir) {
    Get-ChildItem -LiteralPath $commandsDir -Filter '*.md' | Where-Object { $_.Name -ne 'README.md' } | ForEach-Object {
        $content = Get-Content -LiteralPath $_.FullName -Raw
        if ($content -notmatch 'skills/' -and $content -notmatch 'adapters/' -and $content -notmatch 'scripts[/\\]') {
            Fail "command-shim: commands/$($_.Name) does not reference skills/, adapters/, or scripts/ -- commands must be thin shims"
        }
    }
}

# ---- 3. profile.json schema ------------------------------------------------
$profilePath = Join-Path $Root 'profile.json'
if (-not (Test-Path -LiteralPath $profilePath)) {
    Fail "profile: profile.json not found at repo root"
} else {
    try {
        $prof = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
        $keys = $prof.PSObject.Properties.Name
        foreach ($k in @('id', 'ticketPrefix', 'ticketSystem', 'defaultMode', 'repos')) {
            if ($keys -notcontains $k) { Fail "profile: missing required key '$k'" }
        }
        if (($keys -contains 'defaultMode') -and $prof.defaultMode -notin @('branch', 'worktree')) {
            Fail "profile: defaultMode '$($prof.defaultMode)' must be 'branch' or 'worktree'"
        }
        if (($keys -contains 'repos') -and -not @($prof.repos).Count) {
            Fail "profile: repos array is empty"
        }
        if ($keys -notcontains 'stacks' -or
            $prof.stacks.PSObject.Properties.Name -notcontains 'startCommand') {
            Fail "profile: stacks.startCommand is missing"
        }
    } catch {
        Fail "profile: profile.json is not valid JSON -- $($_.Exception.Message)"
    }
}

# ---- 4. Retired artifacts banned -------------------------------------------
$plansDir = Join-Path $Root 'plans'
if (Test-Path -LiteralPath $plansDir) {
    foreach ($pat in @('WI*-impl-prompt.md', 'WI*-workitem.json', 'scorecard-trend.md')) {
        @(Get-ChildItem -LiteralPath $plansDir -Filter $pat -ErrorAction SilentlyContinue) | ForEach-Object {
            Fail "retired-artifact: plans/$($_.Name) was superseded -- delete it (see _shared/ticket-artifacts.md)"
        }
    }
}

# ---- 5. No hardcoded worktree paths in skills/workflow/** and commands/*.md --
# Match only when a real ticket number (digits) appears — WI<n> is a documentation
# placeholder and is intentionally allowed in skill descriptions.
$pathPat = 'source[/\\\\]worktrees[/\\\\]WI\d+'
foreach ($dir in @((Join-Path $Root 'skills' 'workflow'), (Join-Path $Root 'commands'))) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    Get-ChildItem -LiteralPath $dir -Recurse -Filter '*.md' | ForEach-Object {
        $rel = $_.FullName.Substring($Root.Length + 1)
        $content = Get-Content -LiteralPath $_.FullName -Raw
        if ($content -match $pathPat) {
            Fail "hardcoded-path: $rel contains literal 'source/worktrees/WI' -- use Resolve-TicketRoot"
        }
    }
}

# ---- 6. Ledger column contract ---------------------------------------------
$ledgerPath = Join-Path $Root 'plans' 'ticket-ledger.md'
if (Test-Path -LiteralPath $ledgerPath) {
    $hdr = Get-Content -LiteralPath $ledgerPath | Where-Object { $_ -match 'Ticket.*Type.*Closed' } | Select-Object -First 1
    if (-not $hdr) { $hdr = '' }
    $required = @('Ticket', 'Type', 'Closed', 'Mode', 'Hours', 'Pts', 'E', 'C', '$tok', 'Ctx%', 'PR')
    $missing = @($required | Where-Object { $hdr -notmatch [regex]::Escape($_) })
    if ($missing.Count) {
        Fail "ledger-columns: plans/ticket-ledger.md header missing column(s): $($missing -join ', ')"
    }
} else {
    Fail "ledger-columns: plans/ticket-ledger.md not found"
}

# ---- 7. INDEX.md has the two contract docs ---------------------------------
$indexPath = Join-Path $Root 'INDEX.md'
if (Test-Path -LiteralPath $indexPath) {
    $idx = Get-Content -LiteralPath $indexPath -Raw
    foreach ($c in @('ticket-artifacts.md', 'severity-and-output.md')) {
        if ($idx -notmatch [regex]::Escape($c)) {
            Fail "index-contracts: INDEX.md is missing a row for '$c'"
        }
    }
} else {
    Fail "index-contracts: INDEX.md not found"
}

# ---- 8. hooks.json present with required events ----------------------------
$hooksPath = Join-Path $Root 'hooks.json'
if (-not (Test-Path -LiteralPath $hooksPath)) {
    Fail "hooks: hooks.json not found at repo root"
} else {
    try {
        $hooksText = Get-Content -LiteralPath $hooksPath -Raw
        # Validate JSON
        $null = $hooksText | ConvertFrom-Json
        if ($hooksText -notmatch 'sessionStart') {
            Fail "hooks: hooks.json does not define a sessionStart hook"
        }
        # closeout-read-guard or equivalent -- look for 'closeout' keyword
        if ($hooksText -notmatch 'closeout') {
            Fail "hooks: hooks.json does not define a closeout hook (read-guard)"
        }
    } catch {
        Fail "hooks: hooks.json is not valid JSON -- $($_.Exception.Message)"
    }
}

# ---- 9. Template-only: workflow skills must not mention TMO specifics ------
$isTemplate = $false
if (Test-Path -LiteralPath $profilePath) {
    try {
        $p = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
        $isTemplate = ($p.PSObject.Properties.Name -contains 'id') -and $p.id -ne 'tmo'
    } catch { }
}

if ($isTemplate) {
    $tmoTerms = @('TmoPro', 'IIS Express', 'Custom.StoryPointsActual')
    $wfDir = Join-Path $Root 'skills' 'workflow'
    if (Test-Path -LiteralPath $wfDir) {
        Get-ChildItem -LiteralPath $wfDir -Recurse -Filter '*.md' | ForEach-Object {
            $rel = $_.FullName.Substring($Root.Length + 1)
            $content = Get-Content -LiteralPath $_.FullName -Raw
            foreach ($term in $tmoTerms) {
                if ($content -match [regex]::Escape($term)) {
                    Fail "template-vanilla: $rel mentions '$term' -- TMO content must stay in the tmo profile"
                }
            }
        }
    }
}

# ---- Report ----------------------------------------------------------------
if ($violations.Count -eq 0) {
    Write-Host "[PASS] Agentic flow: all checks passed." -ForegroundColor Green
    exit 0
}

$label = if ($WarnOnly) { "[WARN]" } else { "[FAIL]" }
$color = if ($WarnOnly) { "Yellow" } else { "Red" }
Write-Host "$label Agentic flow: $($violations.Count) violation(s):" -ForegroundColor $color
foreach ($v in $violations) {
    Write-Host "  $v" -ForegroundColor $color
}
if ($WarnOnly) { exit 0 }
exit 1
