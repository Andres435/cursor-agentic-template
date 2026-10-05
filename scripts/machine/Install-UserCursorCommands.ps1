<#
.SYNOPSIS
    Install or remove the user-level slash-command junction.

.DESCRIPTION
    Cursor paints icon and color on user skills. Command markdown stays a gear,
    so this script does not publish commands/ into the slash list. It junctions:

      %USERPROFILE%\.cursor\skills\<skill>    -> this repo's skills/<skill>

    and removes a commands junction that points at this repo. The skills folder
    itself is not replaced, so other user skills stay. The Cursor plugin manifest
    points commands and skills at an empty folder so the picker is not also
    filled with icon-less plugin copies.

    -ForWorktrees is the same install. Ticket windows see these user links.

.PARAMETER ForWorktrees
    Same as the default install. Kept so older setup docs still link commands.

.PARAMETER Copy
    With -ForWorktrees, copy files instead of creating a junction.

.PARAMETER Force
    With -ForWorktrees, replace an existing commands link or folder.

.PARAMETER WhatIf
    Preview only.

.PARAMETER Remove
    Unlink only the commands junction and skill junctions that point at this repo.

.EXAMPLE
    .\Install-UserCursorCommands.ps1
    # Link each skill so slash badges keep their icons. Drop this repo's commands link.

.EXAMPLE
    .\Install-UserCursorCommands.ps1 -Remove
    # Drop this repo's user-level command and skill links.
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

. (Join-Path $PSScriptRoot ".." "_ServiceLauncherLib.ps1")

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$UserCursor = Join-Path $env:USERPROFILE '.cursor'

function Test-IsReparsePoint {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $item = Get-Item $Path -Force
    return [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Remove-RepoJunction {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Source
    )
    $dest = Join-Path $UserCursor $Name
    if (-not (Test-Path $dest)) { return }
    $isLink = Test-IsReparsePoint -Path $dest
    $currentTarget = $null
    if ($isLink) {
        try {
            $currentTarget = (Get-Item $dest -Force).Target
            if ($currentTarget -is [array]) { $currentTarget = $currentTarget[0] }
        } catch { }
    }
    $pointsHere = $false
    if ($currentTarget) {
        $pointsHere = ([IO.Path]::GetFullPath($currentTarget)).TrimEnd('\') -eq
                      ([IO.Path]::GetFullPath($Source)).TrimEnd('\')
    }
    if (-not ($isLink -and $pointsHere)) { return }
    if ($WhatIf) {
        Write-LauncherDoing "[WhatIf] Would remove leftover $Name link $dest"
        return
    }
    (Get-Item $dest -Force).Delete()
    Write-LauncherOk "Removed leftover $Name link $dest"
}

if (-not $Remove -and -not (Test-Path $UserCursor) -and -not $WhatIf) {
    New-Item -ItemType Directory -Path $UserCursor -Force | Out-Null
    Write-LauncherOk "Created $UserCursor"
}

$skillsSource = Join-Path $RepoRoot 'skills'
$userSkills = Join-Path $UserCursor 'skills'

if ($Remove) {
    Remove-RepoJunction -Name 'commands' -Source (Join-Path $RepoRoot 'commands')
    if (Test-Path -LiteralPath $userSkills) {
        Get-ChildItem -LiteralPath $skillsSource -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-RepoJunction -Name (Join-Path 'skills' $_.Name) -Source $_.FullName
        }
    }
    Write-Host ""
    Write-Host "Reload Cursor. This repo's user-level skill links are removed." -ForegroundColor Green
    Write-Host ""
    return
}

if (-not (Test-Path -LiteralPath $userSkills) -and -not $WhatIf) {
    New-Item -ItemType Directory -Path $userSkills -Force | Out-Null
}

$slashNames = @()
$profilePath = Join-Path $RepoRoot 'profile.json'
if (Test-Path -LiteralPath $profilePath) {
    $prof = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($prof.PSObject.Properties.Name -contains 'slashCommands') {
        $slashNames = @($prof.slashCommands)
    }
}
if (-not $slashNames.Count) {
    throw "profile.json slashCommands is empty. The slash menu lists only that array."
}

Get-ChildItem -LiteralPath $skillsSource -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $destSkill = Join-Path $userSkills $_.Name
    $srcSkill = $_.FullName
    if ($slashNames -notcontains $_.Name) {
        Remove-RepoJunction -Name (Join-Path 'skills' $_.Name) -Source $srcSkill
        return
    }
    if ($WhatIf) {
        Write-LauncherDoing "[WhatIf] Would junction $destSkill -> $srcSkill"
        return
    }
    if (Test-Path -LiteralPath $destSkill) {
        if (Test-IsReparsePoint -Path $destSkill) {
            $current = (Get-Item -LiteralPath $destSkill -Force).Target
            if ($current -is [array]) { $current = $current[0] }
            $same = $current -and (([IO.Path]::GetFullPath($current)).TrimEnd('\') -eq ([IO.Path]::GetFullPath($srcSkill)).TrimEnd('\'))
            if ($same) {
                Write-LauncherSkip "$destSkill already points at this repo"
                return
            }
            if (-not $Force) {
                Write-LauncherFail "$destSkill is a link to elsewhere ($current). Re-run with -Force to replace."
                return
            }
            (Get-Item -LiteralPath $destSkill -Force).Delete()
        } else {
            Write-LauncherSkip "$destSkill is a real folder - left in place"
            return
        }
    }
    New-Item -ItemType Junction -Path $destSkill -Target $srcSkill | Out-Null
    Write-LauncherOk "Junctioned $destSkill -> $srcSkill"
}

Remove-RepoJunction -Name 'commands' -Source (Join-Path $RepoRoot 'commands')

Write-Host ""
Write-Host "Reload Cursor (Developer: Reload Window). Slash badges come from the user skill links. A commands folder link is a gear duplicate, so this repo's is removed." -ForegroundColor Green
Write-Host ""
