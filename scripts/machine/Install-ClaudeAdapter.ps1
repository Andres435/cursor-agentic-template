<#
.SYNOPSIS
    Writes the Claude Code overlay at the workspace root so this folder can run
    as a Claude plugin on an Anthropic plan.

.DESCRIPTION
    Claude Code is one of three IDEs that load this workflow. This script only drops thin
    pointers next to the product code:

      <workspace>/CLAUDE.md   <- imports <folder>/AGENTS.md + the Claude model overlay
      <workspace>/.mcp.json   <- copy of this folder's mcp.json, when it declares servers

    The workspace root defaults to the parent of this folder (the app root when this folder
    is <app>/.cursor, or source/repos in a multi-repo layout). The CLAUDE.md template is
    adapters/claude/workspace-CLAUDE.md; {{folder}} and {{plugin}} are filled in here.

.PARAMETER WorkspaceRoot
    Folder that should receive CLAUDE.md. Defaults to the parent of this folder.

.PARAMETER Force
    Rewrite CLAUDE.md / .mcp.json even when they already match. A copy that differs
    from the repo is replaced without -Force (the old file is kept as *.previous):
    a stale overlay loads wrong instructions into every Claude session.

.PARAMETER Check
    Report whether the installed CLAUDE.md / .mcp.json match the repo; write nothing.
    Exit 1 when either is stale or missing. /doctor runs this.

.PARAMETER Quiet
    Suppress the banner and start-command footer.

.PARAMETER WhatIf
    Preview only.

.EXAMPLE
    .\Install-ClaudeAdapter.ps1

.EXAMPLE
    .\Install-ClaudeAdapter.ps1 -Check

.EXAMPLE
    .\Install-ClaudeAdapter.ps1 -WorkspaceRoot C:\src\my-app -Force
#>

[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [switch]$Force,
    [switch]$Check,
    [switch]$Quiet,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path (Join-Path $PSScriptRoot '..') '_ServiceLauncherLib.ps1')

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$folder = Split-Path $RepoRoot -Leaf
$template = Join-Path (Join-Path (Join-Path $RepoRoot 'adapters') 'claude') 'workspace-CLAUDE.md'
$mcpSource = Join-Path $RepoRoot 'mcp.json'
if (-not $WorkspaceRoot) { $WorkspaceRoot = Split-Path $RepoRoot -Parent }

$plugin = 'agentic'
$manifest = Join-Path (Join-Path $RepoRoot '.claude-plugin') 'plugin.json'
if (Test-Path -LiteralPath $manifest) {
    try {
        $name = [string](Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).name
        if ($name) { $plugin = $name }
    } catch { }
}

$script:stale = 0

# Same text after line endings and trailing whitespace are normalized.
function Get-NormalizedText {
    param([string]$Text)
    return ([string]$Text -replace "`r`n", "`n").TrimEnd()
}

function Test-SameText {
    param([string]$Path, [string]$Expected)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    return (Get-NormalizedText (Get-Content -LiteralPath $Path -Raw)) -ceq (Get-NormalizedText $Expected)
}

# -Check: report one installed file against the text it should hold. Never writes.
function Test-Installed {
    param([string]$Dest, [string]$Expected, [string]$Label)
    if (-not (Test-Path -LiteralPath $Dest)) {
        Write-LauncherFail "$Label missing: $Dest (run Install-ClaudeAdapter.ps1)"
        $script:stale++
    } elseif (-not (Test-SameText $Dest $Expected)) {
        Write-LauncherFail "$Label is stale: $Dest differs from this folder (run Install-ClaudeAdapter.ps1 to refresh)"
        $script:stale++
    } else {
        Write-LauncherOk "$Label is current: $Dest"
    }
}

# Before replacing a copy that differs, keep it beside the new one.
function Save-Previous {
    param([string]$Dest)
    $prev = "$Dest.previous"
    Copy-Item -LiteralPath $Dest -Destination $prev -Force
    Write-LauncherSkip "Kept the old copy as $prev"
}

function Install-ClaudeMarkdown {
    if (-not (Test-Path -LiteralPath $template)) { throw "Missing Claude overlay template: $template" }
    if (-not (Test-Path -LiteralPath $WorkspaceRoot)) { throw "Workspace folder does not exist: $WorkspaceRoot" }
    $dest = Join-Path $WorkspaceRoot 'CLAUDE.md'
    $text = (Get-Content -LiteralPath $template -Raw).Replace('{{folder}}', $folder).Replace('{{plugin}}', $plugin)
    if ($Check) { Test-Installed -Dest $dest -Expected $text -Label 'CLAUDE.md'; return }
    if ((Test-Path -LiteralPath $dest) -and -not $Force -and (Test-SameText $dest $text)) {
        Write-LauncherOk "CLAUDE.md is current: $dest"
        return
    }
    if ($WhatIf) {
        Write-LauncherDoing "[WhatIf] Would write $dest from adapters/claude/workspace-CLAUDE.md"
        return
    }
    if ((Test-Path -LiteralPath $dest) -and -not (Test-SameText $dest $text)) { Save-Previous $dest }
    [System.IO.File]::WriteAllText($dest, $text, (New-Object System.Text.UTF8Encoding $false))
    Write-LauncherOk "Wrote CLAUDE.md -> $dest"
}

# A copy, not a link: a file link needs admin or developer mode on Windows.
function Install-McpFile {
    if (-not (Test-Path -LiteralPath $mcpSource)) { Write-LauncherSkip "No mcp.json - skipped .mcp.json"; return }
    $servers = (Get-Content -LiteralPath $mcpSource -Raw | ConvertFrom-Json).mcpServers
    if (-not $servers -or -not @($servers.PSObject.Properties).Count) {
        Write-LauncherSkip "mcp.json declares no servers - skipped .mcp.json"
        return
    }
    $dest = Join-Path $WorkspaceRoot '.mcp.json'
    $text = Get-Content -LiteralPath $mcpSource -Raw
    if ($Check) { Test-Installed -Dest $dest -Expected $text -Label '.mcp.json'; return }
    if ((Test-Path -LiteralPath $dest) -and -not $Force -and (Test-SameText $dest $text)) {
        Write-LauncherOk ".mcp.json is current: $dest"
        return
    }
    if ($WhatIf) { Write-LauncherDoing "[WhatIf] Would copy $mcpSource -> $dest"; return }
    if ((Test-Path -LiteralPath $dest) -and -not (Test-SameText $dest $text)) { Save-Previous $dest }
    Copy-Item -LiteralPath $mcpSource -Destination $dest -Force
    Write-LauncherOk "Copied mcp.json -> $dest"
}

if (-not $Quiet -and -not $Check) {
    Write-Host ""
    Write-Host "=== Claude Code adapter ===" -ForegroundColor Cyan
    Write-Host "Plugin folder: $RepoRoot" -ForegroundColor DarkGray
    Write-Host "Workspace:     $WorkspaceRoot" -ForegroundColor DarkGray
}

Install-ClaudeMarkdown
Install-McpFile

if (-not $Quiet -and -not $Check) {
    Write-Host ""
    Write-Host "Start Claude Code with:" -ForegroundColor Green
    Write-Host "  cd `"$WorkspaceRoot`""
    Write-Host "  claude --plugin-dir `"$RepoRoot`""
    Write-Host "Commands are namespaced: /$($plugin):start-ticket  /$($plugin):complete-task  /$($plugin):prep-pr"
    Write-Host "Details: adapters/claude/README.md"
    Write-Host ""
}

if ($Check) { exit ([int]($script:stale -gt 0)) }
