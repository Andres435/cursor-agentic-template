<#
.SYNOPSIS
    Link each skill into the user Cursor skills folder so slash badges keep their icons.
#>
[CmdletBinding()]
param(
    [switch]$ForWorktrees,
    [switch]$Remove,
    [switch]$Copy,
    [switch]$Force,
    [switch]$WhatIf
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$UserCursor = Join-Path $env:USERPROFILE '.cursor'
$skillsSource = Join-Path $RepoRoot 'skills'
$userSkills = Join-Path $UserCursor 'skills'

function Test-IsReparsePoint {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    return [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}
function Remove-RepoLink {
    param([string]$Dest, [string]$Source)
    if (-not (Test-Path -LiteralPath $Dest)) { return }
    if (-not (Test-IsReparsePoint $Dest)) { return }
    $current = (Get-Item -LiteralPath $Dest -Force).Target
    if ($current -is [array]) { $current = $current[0] }
    if ($current -and ($current.TrimEnd('\','/') -ne $Source.TrimEnd('\','/'))) { return }
    if ($WhatIf) { Write-Host "[WhatIf] Would remove $Dest"; return }
    (Get-Item -LiteralPath $Dest -Force).Delete()
    Write-Host "Removed $Dest"
}
function New-SkillLink {
    param([string]$Dest, [string]$Source)
    try {
        New-Item -ItemType Junction -Path $Dest -Target $Source -ErrorAction Stop | Out-Null
    } catch {
        New-Item -ItemType SymbolicLink -Path $Dest -Target $Source | Out-Null
    }
}

if (-not $Remove -and -not (Test-Path $UserCursor) -and -not $WhatIf) {
    New-Item -ItemType Directory -Path $UserCursor -Force | Out-Null
}
if ($Remove) {
    Remove-RepoLink -Dest (Join-Path $UserCursor 'commands') -Source (Join-Path $RepoRoot 'commands')
    if (Test-Path -LiteralPath $userSkills) {
        Get-ChildItem -LiteralPath $skillsSource -Directory | ForEach-Object {
            Remove-RepoLink -Dest (Join-Path $userSkills $_.Name) -Source $_.FullName
        }
    }
    Write-Host "Reload Cursor. This repo's user-level skill links are removed."
    return
}
if (-not (Test-Path -LiteralPath $userSkills) -and -not $WhatIf) {
    New-Item -ItemType Directory -Path $userSkills -Force | Out-Null
}
Get-ChildItem -LiteralPath $skillsSource -Directory | ForEach-Object {
    $destSkill = Join-Path $userSkills $_.Name
    $srcSkill = $_.FullName
    if ($WhatIf) { Write-Host "[WhatIf] Would link $destSkill -> $srcSkill"; return }
    if (Test-Path -LiteralPath $destSkill) {
        if (Test-IsReparsePoint $destSkill) {
            $current = (Get-Item -LiteralPath $destSkill -Force).Target
            if ($current -is [array]) { $current = $current[0] }
            if ($current -and ($current.TrimEnd('\','/') -eq $srcSkill.TrimEnd('\','/'))) {
                Write-Host "$destSkill already points here"
                return
            }
            if (-not $Force) {
                Write-Host "$destSkill points elsewhere. Re-run with -Force."
                return
            }
            (Get-Item -LiteralPath $destSkill -Force).Delete()
        } else {
            Write-Host "$destSkill is a real folder - left in place"
            return
        }
    }
    if ($Copy) {
        Copy-Item -LiteralPath $srcSkill -Destination $destSkill -Recurse -Force
    } else {
        New-SkillLink -Dest $destSkill -Source $srcSkill
    }
    Write-Host "Linked $destSkill -> $srcSkill"
}
Remove-RepoLink -Dest (Join-Path $UserCursor 'commands') -Source (Join-Path $RepoRoot 'commands')
Write-Host "Reload Cursor. Slash badges come from the user skill links."
