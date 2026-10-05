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
    Overwrite an existing CLAUDE.md / .mcp.json.

.PARAMETER Quiet
    Suppress the banner and start-command footer.

.PARAMETER WhatIf
    Preview only.

.EXAMPLE
    .\Install-ClaudeAdapter.ps1

.EXAMPLE
    .\Install-ClaudeAdapter.ps1 -WorkspaceRoot C:\src\my-app -Force
#>

[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [switch]$Force,
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

function Install-ClaudeMarkdown {
    if (-not (Test-Path -LiteralPath $template)) { throw "Missing Claude overlay template: $template" }
    if (-not (Test-Path -LiteralPath $WorkspaceRoot)) { throw "Workspace folder does not exist: $WorkspaceRoot" }
    $dest = Join-Path $WorkspaceRoot 'CLAUDE.md'
    if ((Test-Path -LiteralPath $dest) -and -not $Force) {
        Write-LauncherSkip "CLAUDE.md already exists: $dest (pass -Force to replace)"
        return
    }
    if ($WhatIf) {
        Write-LauncherDoing "[WhatIf] Would write $dest from adapters/claude/workspace-CLAUDE.md"
        return
    }
    $text = (Get-Content -LiteralPath $template -Raw).Replace('{{folder}}', $folder).Replace('{{plugin}}', $plugin)
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
    if ((Test-Path -LiteralPath $dest) -and -not $Force) {
        Write-LauncherSkip ".mcp.json already exists: $dest (pass -Force to replace)"
        return
    }
    if ($WhatIf) { Write-LauncherDoing "[WhatIf] Would copy $mcpSource -> $dest"; return }
    Copy-Item -LiteralPath $mcpSource -Destination $dest -Force
    Write-LauncherOk "Copied mcp.json -> $dest"
}

if (-not $Quiet) {
    Write-Host ""
    Write-Host "=== Claude Code adapter ===" -ForegroundColor Cyan
    Write-Host "Plugin folder: $RepoRoot" -ForegroundColor DarkGray
    Write-Host "Workspace:     $WorkspaceRoot" -ForegroundColor DarkGray
}

Install-ClaudeMarkdown
Install-McpFile

if (-not $Quiet) {
    Write-Host ""
    Write-Host "Start Claude Code with:" -ForegroundColor Green
    Write-Host "  cd `"$WorkspaceRoot`""
    Write-Host "  claude --plugin-dir `"$RepoRoot`""
    Write-Host "Commands are namespaced: /$($plugin):start-ticket  /$($plugin):complete-task  /$($plugin):prep-pr"
    Write-Host "Details: adapters/claude/README.md"
    Write-Host ""
}
