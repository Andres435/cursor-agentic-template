#Requires -Version 7
<#
.SYNOPSIS
    List working-tree paths /review-changes may stage for one repo.

.DESCRIPTION
    Candidates are staged, unstaged, and untracked files. Denied paths are
    secret-shaped names, and secret-shaped content (a ClearTextPassword, a
    password= value, an Azure DevOps PAT, a private key) in the lines this
    change adds. This script does not git add or restore. A product
    customize may add its own deny paths in its copy of this script.
    The playbook stages after review.

.PARAMETER RepoPath
    Product repo working tree.

.PARAMETER Json
    Emit one JSON object: repoPath, candidates[], denied[{path, reason}].
    JSON is the only output either way.

.EXAMPLE
    .\Select-TicketStagePaths.ps1 -RepoPath .\app -Json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoPath,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertFrom-StatusPath {
    param([string]$Raw)
    $t = $Raw.Trim()
    if ($t.Length -ge 2 -and $t.StartsWith('"') -and $t.EndsWith('"')) {
        $t = $t.Substring(1, $t.Length - 2) -replace '\\"', '"'
    }
    return ($t -replace '\\', '/')
}

function Get-DenyReason {
    param([string]$Path)
    $name = [IO.Path]::GetFileName(($Path -replace '\\', '/'))
    if ($name -eq '.env' -or $name.StartsWith('.env.')) { return 'secret-shaped name' }
    if ($name -eq 'credentials.json') { return 'secret-shaped name' }
    $ext = [IO.Path]::GetExtension($name)
    if ($ext -in '.pfx', '.pem', '.user') { return 'secret-shaped name' }
    return $null
}

# Matched against ADDED lines only (or a whole untracked file), so a placeholder
# already committed upstream never blocks an unrelated edit to the same file.
# A launcher that writes a feed token into a tracked NuGet.Config is caught this way.
$SecretContentPatterns = @(
    'ClearTextPassword'
    '(?i)\bpassword\s*=\s*[^;"''\s<>$%{}]{4,}'
    '\b[a-z2-7]{52}\b'                            # Azure DevOps PAT (legacy 52-char)
    '\b[A-Za-z0-9]{76}AZDO[A-Za-z0-9]{4}\b'       # Azure DevOps PAT (84-char)
    '-----BEGIN [A-Z ]*PRIVATE KEY-----'
)

function Test-SecretText {
    param([string[]]$Lines)
    foreach ($line in $Lines) {
        foreach ($pattern in $SecretContentPatterns) {
            if ($line -match $pattern) { return $true }
        }
    }
    return $false
}

function Get-SecretContentReason {
    param([string]$Path, [string]$Status)
    if ($Status.Contains('D')) { return $null }
    $full = Join-Path $RepoPath $Path
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { return $null }
    if ((Get-Item -LiteralPath $full).Length -gt 1MB) { return $null }

    if ($Status -eq '??') {
        $text = [IO.File]::ReadAllText($full)
        if ($text.IndexOf([char]0) -ge 0) { return $null }  # binary
        $lines = $text -split "`r?`n"
    } else {
        # Staged plus unstaged edits against HEAD, added lines only.
        $diff = @(& git -C $RepoPath diff HEAD --no-color --no-ext-diff -U0 -- $Path 2>$null)
        $lines = @($diff | Where-Object { $_.StartsWith('+') -and -not $_.StartsWith('+++') } |
            ForEach-Object { $_.Substring(1) })
    }
    if (Test-SecretText $lines) { return 'secret-shaped content' }
    return $null
}

if (-not (Test-Path -LiteralPath $RepoPath)) {
    throw "Repo path not found: $RepoPath"
}

$inside = & git -C $RepoPath rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $inside -ne 'true') {
    throw "Not a git working tree: $RepoPath"
}

$lines = @(& git -C $RepoPath status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) {
    throw "git status failed in $RepoPath"
}

$candidates = [System.Collections.Generic.List[string]]::new()
$denied = [System.Collections.Generic.List[object]]::new()
$seen = @{}

foreach ($line in $lines) {
    if (-not $line -or $line.Length -lt 4) { continue }
    $rest = $line.Substring(3)
    $path = $rest
    $arrow = $rest.IndexOf(' -> ')
    if ($arrow -ge 0) { $path = $rest.Substring($arrow + 4) }
    $path = ConvertFrom-StatusPath $path
    if (-not $path -or $seen.ContainsKey($path)) { continue }
    $seen[$path] = $true
    $reason = Get-DenyReason $path
    if (-not $reason) { $reason = Get-SecretContentReason -Path $path -Status $line.Substring(0, 2) }
    if ($reason) {
        $denied.Add([pscustomobject]@{ path = $path; reason = $reason })
    } else {
        $candidates.Add($path)
    }
}

$full = (Resolve-Path -LiteralPath $RepoPath).Path -replace '\\', '/'
$candJson = (@($candidates | Sort-Object) | ForEach-Object {
    '"' + ($_ -replace '\\', '\\' -replace '"', '\"') + '"'
}) -join ','
$denyJson = (@($denied | Sort-Object path) | ForEach-Object {
    $p = $_.path -replace '\\', '\\' -replace '"', '\"'
    $r = $_.reason -replace '"', '\"'
    '{"path":"' + $p + '","reason":"' + $r + '"}'
}) -join ','
$repoJson = $full -replace '\\', '\\' -replace '"', '\"'
Write-Output ('{"repoPath":"' + $repoJson + '","candidates":[' + $candJson + '],"denied":[' + $denyJson + ']}')
