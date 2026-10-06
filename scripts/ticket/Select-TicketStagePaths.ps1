<#
.SYNOPSIS
    List working-tree paths /review-changes may stage for one repo.

.DESCRIPTION
    Candidates are staged, unstaged, and untracked files. Denied paths are
    secret-shaped names. This script does not git add or restore. A product
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
