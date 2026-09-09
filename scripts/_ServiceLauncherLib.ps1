<#
.SYNOPSIS
    Minimal launcher lib for the agentic template (branch-mode, single-repo).
    Provides the same public surface as the TMO _ServiceLauncherLib.ps1 so
    scripts/ticket/*.ps1 dot-sources work without modification.
#>

Set-StrictMode -Version Latest

# ---- output helpers -------------------------------------------------------
function Write-LauncherFail  { param($msg) Write-Host "   [FAIL] $msg" -ForegroundColor Red }
function Write-LauncherOk    { param($msg) Write-Host "   [OK]   $msg" -ForegroundColor Green }
function Write-LauncherSkip  { param($msg) Write-Host "   [SKIP] $msg" -ForegroundColor DarkGray }

# ---- ticket prefix --------------------------------------------------------
function Get-WorkflowTicketPrefix {
    if ($script:_ticketPrefix) { return $script:_ticketPrefix }
    $profilePath = Join-Path $PSScriptRoot '..' 'profile.json'
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
    return (Resolve-Path -LiteralPath $ReposRoot -ErrorAction SilentlyContinue)?.Path ?? $ReposRoot
}

function Get-TicketWorktreeRoot {
    param([string]$ReposRoot, [string]$TicketId)
    # Template default layout: no worktrees directory.
    return Join-Path (Split-Path $ReposRoot -Parent) 'worktrees' $TicketId
}

# ---- manifest helpers -----------------------------------------------------
function Get-TicketManifest {
    param([string]$ScriptRoot, [string]$Ticket)
    $planDir = Join-Path (Split-Path (Split-Path $ScriptRoot -Parent) -Parent) 'plans'
    $path    = Join-Path $planDir "$Ticket-manifest.json"
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
