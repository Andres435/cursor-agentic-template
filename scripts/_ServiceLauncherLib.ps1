<#
.SYNOPSIS
    Minimal launcher lib for the agentic template (branch-mode, single-repo).
    Provides the same public surface as the TMO _ServiceLauncherLib.ps1 so
    scripts/ticket/*.ps1 dot-sources work without modification.

    Windows PowerShell 5.1 on the work machine; pwsh on GitHub/home.
    Nested Join-Path only (5.1 accepts one ChildPath). No ?. / ?? operators.
#>

Set-StrictMode -Version Latest

# Must be assigned before first read: StrictMode Latest throws on unset $script: vars.
$script:_ticketPrefix = $null

# ---- output helpers -------------------------------------------------------
function Write-LauncherFail  { param($msg) Write-Host "   [FAIL] $msg" -ForegroundColor Red }
function Write-LauncherOk    { param($msg) Write-Host "   [OK]   $msg" -ForegroundColor Green }
function Write-LauncherSkip  { param($msg) Write-Host "   [SKIP] $msg" -ForegroundColor DarkGray }

# ---- ticket prefix --------------------------------------------------------
function Get-WorkflowTicketPrefix {
    if ($script:_ticketPrefix) { return $script:_ticketPrefix }
    $profilePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'profile.json'
    if (Test-Path -LiteralPath $profilePath) {
        try {
            $p = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
            if ($p.ticketPrefix) {
                $script:_ticketPrefix = [string]$p.ticketPrefix
                return $script:_ticketPrefix
            }
        } catch { }
    }
    $script:_ticketPrefix = 'WI'
    return 'WI'
}

<#
.SYNOPSIS
    Normalizes a raw work-item string to <prefix><n>.
    Returns $null for empty/invalid input.
#>
function ConvertTo-LauncherTicketId {
    param([string]$Raw)
    if (-not $Raw) { return $null }
    $digits = ($Raw -replace '[^\d]', '')
    if (-not $digits) { return $null }
    return (Get-WorkflowTicketPrefix) + $digits
}

# ---- repo-root helpers ----------------------------------------------------
function Get-CanonicalReposRoot {
    param([string]$ReposRoot)
    $resolved = Resolve-Path -LiteralPath $ReposRoot -ErrorAction SilentlyContinue
    if ($resolved) { return $resolved.Path }
    return $ReposRoot
}

function Get-TicketWorktreeRoot {
    param([string]$ReposRoot, [string]$TicketId)
    # Template default layout: no worktrees directory.
    return (Join-Path (Join-Path (Split-Path $ReposRoot -Parent) 'worktrees') $TicketId)
}

# ---- manifest helpers -----------------------------------------------------
function Get-TicketManifest {
    param([string]$ScriptRoot, [string]$Ticket)
    $digits = $Ticket -replace '[^\d]', ''
    if (-not $digits) { return $null }
    if ($Ticket -match '^(?<pre>[A-Za-z]+-?)\d') {
        $ticketId = $Matches['pre'] + $digits
    } else {
        $ticketId = ConvertTo-LauncherTicketId -Raw $Ticket
    }
    if (-not $ticketId) { return $null }
    $parent = Split-Path $ScriptRoot -Parent
    $repoRoot = if ((Split-Path $parent -Leaf) -eq 'scripts') { Split-Path $parent -Parent } else { $parent }
    $planDir = Join-Path $repoRoot 'plans'
    $path    = Join-Path $planDir "$ticketId-manifest.json"
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try { return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json } catch { return $null }
}

function Get-LauncherManifestValue {
    param($Manifest, [string]$Property)
    if (-not $Manifest) { return $null }
    if (-not ($Manifest.PSObject.Properties.Name -contains $Property)) { return $null }
    return $Manifest.$Property
}

# ---- git helpers ----------------------------------------------------------
function Test-GitWorktree {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        $out = git -C $Path rev-parse --git-dir 2>$null
        return [bool]$out
    } catch { return $false }
}
