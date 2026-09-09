<#
.SYNOPSIS
    First-time (or refresh) setup for this Cursor agentic workflow on the current machine.

.DESCRIPTION
    Git does not install Cursor extensions, user settings, or user-level command links.
    Run this once after cloning/pulling cursor-agentic-workspace into source\repos\.cursor.

    Phases:
      0. Preflight   - report which prerequisites this machine has (never blocks)
      1. Extensions  - Install-CursorExtensions.ps1
      2. User config - Apply-CursorUserConfig.ps1 (settings + keybindings +
                       Install-UserCursorCommands.ps1 so / commands work from worktrees)
      3. Cockpit     - New-CockpitWorkspace.ps1 (only with -GenerateCockpit)
      4. Claude      - Install-ClaudeAdapter.ps1 (CLAUDE.md + .mcp.json at the workspace root)
      5. Verify      - re-check what actually landed, then print a summary

    Every phase is isolated: one failing phase is recorded and reported, it does not
    abort the rest of the bootstrap. The final summary is the authoritative result -
    read it rather than assuming success from the absence of red text.

    Safe to re-run. Already-installed extensions and already-correct links are skipped.

.PARAMETER IncludeOptionalExtensions
    Pass -IncludeOptional to Install-CursorExtensions.ps1.

.PARAMETER ForceKeybindings
    Pass -ForceKeybindings to Apply-CursorUserConfig.ps1.

.PARAMETER SkipExtensions
    Skip extension install (settings + command links only).

.PARAMETER SkipUserConfig
    Skip Apply-CursorUserConfig (extensions only; not recommended for first setup).

.PARAMETER SkipUserCommands
    Pass -SkipUserCommands to Apply-CursorUserConfig.ps1 (settings/keys only).

.PARAMETER GenerateCockpit
    Also run New-CockpitWorkspace.ps1 -Open after config.

.PARAMETER SkipClaudeAdapter
    Skip writing the Claude Code overlay (workspace CLAUDE.md / .mcp.json).

.PARAMETER SkipPreflight
    Skip the prerequisite report (phase 0).

.PARAMETER WhatIf
    Preview child scripts without writing.

.EXAMPLE
    .\Initialize-WorkflowMachine.ps1

.EXAMPLE
    .\Initialize-WorkflowMachine.ps1 -IncludeOptionalExtensions -GenerateCockpit

.EXAMPLE
    .\Initialize-WorkflowMachine.ps1 -WhatIf
    Preview every phase, including the prerequisite report, without changing anything.

.NOTES
    See MACHINE-SETUP.md.
#>

[CmdletBinding()]
param(
    [switch]$IncludeOptionalExtensions,
    [switch]$ForceKeybindings,
    [switch]$SkipExtensions,
    [switch]$SkipUserConfig,
    [switch]$SkipUserCommands,
    [switch]$GenerateCockpit,
    [switch]$SkipClaudeAdapter,
    [switch]$SkipPreflight,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here     = $PSScriptRoot
$RepoRoot = Split-Path (Split-Path $here -Parent) -Parent
$results  = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param(
        [Parameter(Mandatory)][string]$Phase,
        [Parameter(Mandatory)][ValidateSet('OK', 'FAILED', 'SKIPPED', 'PREVIEW', 'WARN')][string]$Status,
        [string]$Detail = ''
    )
    $results.Add([pscustomobject]@{ Phase = $Phase; Status = $Status; Detail = $Detail })
}

<#
.SYNOPSIS
    Runs one bootstrap phase, recording its outcome instead of letting a failure
    abort the whole machine setup.

.DESCRIPTION
    A half-configured machine with a clear report beats a hard stop on phase 1
    with no summary - the person running this usually cannot tell which of the
    later phases would also have failed. Catches terminating errors AND a
    non-zero exit code from a child script (child scripts signal partial failure
    with `exit 1` rather than throwing, so both paths must be checked).
#>
function Invoke-Phase {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Body
    )
    Write-Host ""
    Write-Host "--- $Name ---" -ForegroundColor Cyan
    $global:LASTEXITCODE = 0
    try {
        & $Body
        if ($LASTEXITCODE -ne 0) {
            Add-Result -Phase $Name -Status 'FAILED' -Detail "child script exited $LASTEXITCODE"
            Write-Host "[$Name] reported a problem (exit $LASTEXITCODE) - continuing with the next phase." -ForegroundColor Yellow
        } else {
            Add-Result -Phase $Name -Status $(if ($WhatIf) { 'PREVIEW' } else { 'OK' })
        }
    } catch {
        Add-Result -Phase $Name -Status 'FAILED' -Detail $_.Exception.Message
        Write-Host "[$Name] FAILED: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Continuing with the next phase." -ForegroundColor Yellow
    }
}

function Test-ToolPresent {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

Write-Host ""
Write-Host "=== Initialize Cursor workflow machine ===" -ForegroundColor Cyan
Write-Host "Repo:      $RepoRoot" -ForegroundColor DarkGray
Write-Host "Workspace: $(Split-Path $RepoRoot -Parent)" -ForegroundColor DarkGray
if ($WhatIf) { Write-Host "MODE:      -WhatIf (nothing will be written)" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# 0. Preflight - report, never block
# ---------------------------------------------------------------------------
# Deliberately non-blocking: most of these are needed by the WORKFLOW later
# (MCP servers, builds, worktrees), not by this script, and a new machine is
# usually missing one or two. Showing the whole picture once is more useful
# than failing at the first gate, being fixed, then failing at the next.
$missingRequired = @()
if (-not $SkipPreflight) {
    Write-Host ""
    Write-Host "--- 0. Preflight (prerequisite report) ---" -ForegroundColor Cyan

    $checks = @(
        @{ Name = 'cursor CLI'; Present = (Test-ToolPresent 'cursor'); Required = (-not $SkipExtensions)
           Why = 'installs extensions; ships with Cursor'; Fix = 'Open Cursor once, or add its bin\ folder to PATH' }
        @{ Name = 'git';        Present = (Test-ToolPresent 'git');    Required = $true
           Why = 'repos + per-ticket worktrees'; Fix = 'https://git-scm.com' }
        @{ Name = 'node / npx'; Present = (Test-ToolPresent 'npx');    Required = $true
           Why = 'ado + sonarqube MCP servers start via npx'; Fix = 'Install Node.js LTS' }
        @{ Name = 'az CLI';     Present = (Test-ToolPresent 'az');     Required = $true
           Why = 'ADO MCP auth, Tmo NuGet feed token, Key Vault'; Fix = 'Install Azure CLI, then: az login' }
        @{ Name = 'dotnet SDK'; Present = (Test-ToolPresent 'dotnet'); Required = $true
           Why = 'TmoPro builds / tests / warning sweep'; Fix = 'Install the .NET SDK matching TmoPro global.json' }
        @{ Name = 'mkcert';     Present = (Test-ToolPresent 'mkcert'); Required = $false
           Why = 'local HTTPS certs for the React wrapper stack'; Fix = 'winget install FiloSottile.mkcert' }
    )

    foreach ($c in $checks) {
        if ($c.Present) {
            Write-Host ("   [OK]   {0,-12} {1}" -f $c.Name, $c.Why) -ForegroundColor Green
        } elseif ($c.Required) {
            $missingRequired += $c.Name
            Write-Host ("   [MISS] {0,-12} {1}" -f $c.Name, $c.Why) -ForegroundColor Red
            Write-Host ("          -> {0}" -f $c.Fix) -ForegroundColor Yellow
        } else {
            Write-Host ("   [--]   {0,-12} {1} (optional for now)" -f $c.Name, $c.Why) -ForegroundColor DarkGray
            Write-Host ("          -> {0}" -f $c.Fix) -ForegroundColor DarkGray
        }
    }

    # Windows PowerShell 5.1 is what the generated workspace tasks invoke as
    # `powershell`. Running this bootstrap under PowerShell 7 still works, but
    # it hides 5.1-only breakage the tasks will hit later.
    if ($PSVersionTable.PSEdition -eq 'Core') {
        Write-Host "   [WARN] Running under PowerShell $($PSVersionTable.PSVersion) (Core)." -ForegroundColor Yellow
        Write-Host "          Generated tasks call Windows PowerShell 5.1 - re-run there if tasks misbehave." -ForegroundColor DarkGray
    }

    # Long paths: the legacy solution nests deep enough that clones/worktrees
    # fail without this, in ways that look like unrelated build errors.
    if (Test-ToolPresent 'git') {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $longPaths = (git config --global core.longpaths 2>$null)
        $ErrorActionPreference = $prevEap
        if ("$longPaths".Trim() -ne 'true') {
            Write-Host "   [WARN] git core.longpaths is not 'true' globally." -ForegroundColor Yellow
            Write-Host "          -> git config --global core.longpaths true" -ForegroundColor Yellow
        } else {
            Write-Host "   [OK]   git core.longpaths=true" -ForegroundColor Green
        }
    }

    # This repo must sit at <workspace>\.cursor for the Claude overlay and the
    # worktree scripts' canonical-root resolution to work.
    if ((Split-Path $RepoRoot -Leaf) -ine '.cursor') {
        Write-Host "   [WARN] This clone is '$(Split-Path $RepoRoot -Leaf)', not '.cursor'." -ForegroundColor Yellow
        Write-Host "          Expected source\repos\.cursor - the Claude overlay and worktree paths assume it." -ForegroundColor DarkGray
    }

    if ($missingRequired.Count -gt 0) {
        Write-Host ""
        Write-Host "   $($missingRequired.Count) required tool(s) missing: $($missingRequired -join ', ')" -ForegroundColor Red
        Write-Host "   Continuing anyway - install them before running a ticket. See MACHINE-SETUP.md section 0." -ForegroundColor Yellow
        Add-Result -Phase '0. Preflight' -Status 'WARN' -Detail "missing: $($missingRequired -join ', ')"
    } else {
        Add-Result -Phase '0. Preflight' -Status 'OK' -Detail 'all required tools present'
    }
} else {
    Add-Result -Phase '0. Preflight' -Status 'SKIPPED' -Detail '-SkipPreflight'
}

# ---------------------------------------------------------------------------
# 1. Extensions
# ---------------------------------------------------------------------------
if (-not $SkipExtensions) {
    Invoke-Phase -Name '1. Extensions' -Body {
        $extArgs = @{}
        if ($IncludeOptionalExtensions) { $extArgs['IncludeOptional'] = $true }
        if ($WhatIf) { $extArgs['WhatIf'] = $true }
        & (Join-Path $here 'Install-CursorExtensions.ps1') @extArgs
    }
} else {
    Add-Result -Phase '1. Extensions' -Status 'SKIPPED' -Detail '-SkipExtensions'
    Write-Host ""
    Write-Host "Skipped extensions (-SkipExtensions)." -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 2. User settings, keybindings, slash commands
# ---------------------------------------------------------------------------
if (-not $SkipUserConfig) {
    Invoke-Phase -Name '2. User config' -Body {
        $cfgArgs = @{}
        if ($ForceKeybindings) { $cfgArgs['ForceKeybindings'] = $true }
        if ($SkipUserCommands) { $cfgArgs['SkipUserCommands'] = $true }
        if ($WhatIf) { $cfgArgs['WhatIf'] = $true }
        & (Join-Path $here 'Apply-CursorUserConfig.ps1') @cfgArgs
    }
} else {
    Add-Result -Phase '2. User config' -Status 'SKIPPED' -Detail '-SkipUserConfig'
    Write-Host ""
    Write-Host "Skipped user config (-SkipUserConfig)." -ForegroundColor DarkGray
    if (-not $SkipUserCommands) {
        # The / commands are the part people notice missing first, so link them
        # even when the rest of the user config was skipped.
        Invoke-Phase -Name '2b. User command links' -Body {
            $cmdArgs = @{}
            if ($WhatIf) { $cmdArgs['WhatIf'] = $true }
            & (Join-Path $here 'Install-UserCursorCommands.ps1') @cmdArgs
        }
    }
}

# ---------------------------------------------------------------------------
# 3. Cockpit workspace (opt-in)
# ---------------------------------------------------------------------------
if ($GenerateCockpit) {
    Invoke-Phase -Name '3. Cockpit workspace' -Body {
        $cockpitArgs = @{ Open = $true }
        if ($WhatIf) { $cockpitArgs['WhatIf'] = $true }
        & (Join-Path $here 'New-CockpitWorkspace.ps1') @cockpitArgs
    }
} else {
    Add-Result -Phase '3. Cockpit workspace' -Status 'SKIPPED' -Detail 'pass -GenerateCockpit'
    Write-Host ""
    Write-Host "Skipped cockpit (pass -GenerateCockpit to create tmo-cockpit.code-workspace)." -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 4. Claude Code overlay
# ---------------------------------------------------------------------------
if (-not $SkipClaudeAdapter) {
    Invoke-Phase -Name '4. Claude overlay' -Body {
        $claudeArgs = @{}
        if ($WhatIf) { $claudeArgs['WhatIf'] = $true }
        & (Join-Path $here 'Install-ClaudeAdapter.ps1') @claudeArgs
    }
} else {
    Add-Result -Phase '4. Claude overlay' -Status 'SKIPPED' -Detail '-SkipClaudeAdapter'
    Write-Host ""
    Write-Host "Skipped Claude adapter (-SkipClaudeAdapter)." -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 4b. Git pre-push runs Assert-AgenticFlow (local repo config only)
# ---------------------------------------------------------------------------
Invoke-Phase -Name '4b. Git pre-push hook' -Body {
    $install = Join-Path $here 'Install-GitPushHook.ps1'
    $hookArgs = @{}
    if ($WhatIf) { $hookArgs['WhatIf'] = $true }
    & $install @hookArgs
}

# ---------------------------------------------------------------------------
# 5. Verify what actually landed
# ---------------------------------------------------------------------------
# Child scripts report their own steps, but a machine can end up subtly wrong
# in ways none of them check: a junction pointing at a previous clone location,
# an extension that exited 0 without installing, a settings merge that silently
# did nothing. This re-reads the end state from disk.
$verifyIssues = @()
if (-not $WhatIf) {
    Write-Host ""
    Write-Host "--- 5. Verify ---" -ForegroundColor Cyan

    foreach ($linkName in @('commands', 'skills')) {
        $dest = Join-Path (Join-Path $env:USERPROFILE '.cursor') $linkName
        $want = Join-Path $RepoRoot $linkName
        if (-not (Test-Path $dest)) {
            if ($SkipUserCommands) {
                Write-Host "   [--]   %USERPROFILE%\.cursor\$linkName not linked (-SkipUserCommands)" -ForegroundColor DarkGray
            } else {
                $verifyIssues += "%USERPROFILE%\.cursor\$linkName is missing - / commands will not load from worktrees"
                Write-Host "   [MISS] %USERPROFILE%\.cursor\$linkName" -ForegroundColor Red
            }
            continue
        }
        $target = $null
        try { $target = (Get-Item $dest -Force).Target; if ($target -is [array]) { $target = $target[0] } } catch { }
        if ($target -and ([IO.Path]::GetFullPath($target)).TrimEnd('\') -ieq ([IO.Path]::GetFullPath($want)).TrimEnd('\')) {
            Write-Host "   [OK]   %USERPROFILE%\.cursor\$linkName -> this repo" -ForegroundColor Green
        } elseif ($target) {
            $verifyIssues += "%USERPROFILE%\.cursor\$linkName points at $target, not this repo - re-run Install-UserCursorCommands.ps1 -Force"
            Write-Host "   [WARN] %USERPROFILE%\.cursor\$linkName -> $target (not this repo)" -ForegroundColor Yellow
        } else {
            Write-Host "   [OK]   %USERPROFILE%\.cursor\$linkName exists (real folder / copy)" -ForegroundColor Green
        }
    }

    $settingsPath = Join-Path $env:APPDATA 'Cursor\User\settings.json'
    if (Test-Path $settingsPath) {
        # git.detectWorktrees is the one setting the cockpit depends on; if the
        # merge worked at all, this is present.
        if ((Get-Content $settingsPath -Raw) -match '"git\.detectWorktrees"\s*:\s*true') {
            Write-Host "   [OK]   Cursor settings include git.detectWorktrees=true" -ForegroundColor Green
        } else {
            $verifyIssues += "git.detectWorktrees is not true in Cursor settings - worktrees will not show in Source Control"
            Write-Host "   [WARN] git.detectWorktrees not true in settings.json" -ForegroundColor Yellow
        }
    } elseif (-not $SkipUserConfig) {
        $verifyIssues += "Cursor settings.json was not created"
        Write-Host "   [MISS] $settingsPath" -ForegroundColor Red
    }

    if (-not $SkipClaudeAdapter -and (Split-Path $RepoRoot -Leaf) -ieq '.cursor') {
        $claudeMd = Join-Path (Split-Path $RepoRoot -Parent) 'CLAUDE.md'
        if (Test-Path $claudeMd) {
            Write-Host "   [OK]   Workspace CLAUDE.md present" -ForegroundColor Green
        } else {
            Write-Host "   [--]   Workspace CLAUDE.md not written (Claude Code is optional)" -ForegroundColor DarkGray
        }
    }

    if ($verifyIssues.Count -gt 0) {
        Add-Result -Phase '5. Verify' -Status 'WARN' -Detail "$($verifyIssues.Count) issue(s)"
    } else {
        Add-Result -Phase '5. Verify' -Status 'OK'
    }
} else {
    Add-Result -Phase '5. Verify' -Status 'SKIPPED' -Detail '-WhatIf'
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host ("=" * 66) -ForegroundColor DarkGray
Write-Host "  Bootstrap summary" -ForegroundColor Cyan
Write-Host ("=" * 66) -ForegroundColor DarkGray
foreach ($r in $results) {
    $color = switch ($r.Status) {
        'OK'      { 'Green' }
        'PREVIEW' { 'Yellow' }
        'SKIPPED' { 'DarkGray' }
        'WARN'    { 'Yellow' }
        default   { 'Red' }
    }
    $line = "  {0,-9} {1,-24} {2}" -f $r.Status, $r.Phase, $r.Detail
    Write-Host $line.TrimEnd() -ForegroundColor $color
}

if ($verifyIssues.Count -gt 0) {
    Write-Host ""
    Write-Host "  Verification found:" -ForegroundColor Yellow
    foreach ($v in $verifyIssues) { Write-Host "    - $v" -ForegroundColor Yellow }
}

$failedCount = @($results | Where-Object { $_.Status -eq 'FAILED' }).Count
Write-Host ""
if ($WhatIf) {
    Write-Host "  Preview only - nothing was changed." -ForegroundColor Yellow
} elseif ($failedCount -gt 0) {
    Write-Host "  $failedCount phase(s) FAILED - see above. Fix, then re-run (safe to re-run)." -ForegroundColor Red
} else {
    Write-Host "  Machine bootstrap finished." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Remaining manual steps - only the ones actually still outstanding
# ---------------------------------------------------------------------------
if (-not $WhatIf) {
    $todo = @()

    # az login state. `az account show` writes to stderr and exits non-zero when
    # logged out, so it needs the same EAP guard as every other native call here.
    if (Test-ToolPresent 'az') {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $null = & az account show 2>$null
        $azOk = ($LASTEXITCODE -eq 0)
        $ErrorActionPreference = $prevEap
        if (-not $azOk) { $todo += 'az login            (ADO MCP, NuGet feed, Key Vault)' }
    } else {
        $todo += 'Install Azure CLI, then az login'
    }

    # A user env var set in another process is not visible here, so read the
    # registry-backed User scope rather than $env: - otherwise this nags about
    # a token that is already set.
    $sonarToken = [Environment]::GetEnvironmentVariable('SONARQUBE_TOKEN', 'User')
    if (-not $sonarToken) { $sonarToken = $env:SONARQUBE_TOKEN }
    if (-not $sonarToken) {
        $todo += 'Set user env SONARQUBE_TOKEN, then fully restart Cursor  (TmoPro Sonar MCP)'
    }

    $todo += 'Developer: Reload Window   (settings, keybindings, / commands)'
    $todo += 'Type / in chat - start-ticket should appear, including from a worktree window'

    Write-Host ""
    Write-Host "  Still to do on this machine:" -ForegroundColor Yellow
    $n = 1
    foreach ($t in $todo) {
        Write-Host ("    {0}. {1}" -f $n, $t)
        $n++
    }
    Write-Host ""
    Write-Host "  Full checklist: MACHINE-SETUP.md (section 8 = day-1 verification)" -ForegroundColor DarkGray
}
Write-Host ""

if ($failedCount -gt 0) { exit 1 }
