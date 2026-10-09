#Requires -Version 7
<#
.SYNOPSIS
    Pick the plugin eval cases a change affects and print the command to run only those.

.DESCRIPTION
    Takes the changed set (branch diff since the merge-base with the base ref, plus
    uncommitted and untracked files), maps each file to eval tags with evals/case-map.psd1,
    and selects every case under evals/ that carries one of those tags. A changed file under
    evals/<case>/ maps to that case's own tags (read from its prompt.md or case.yaml).

    Prints the tags, the matching cases, an estimated cost (cases x 3 runs x $0.30), and the
    ready-to-run `claude plugin eval` command with a --max-cost-usd of 1.5x the estimate.
    Nothing mapped prints "[INFO] no eval needed". Nothing is run.

    A selected case.yaml with context.scaffold_script needs Git bash first on PATH on
    Windows: the WindowsApps bash.exe stub strips the backslashes from the scaffold path and
    those cases score 0. The script warns and prints the PATH fix.

    Base ref, first that resolves (same order as Assert-DocSync.ps1): -Base;
    $env:DOCSYNC_BASE; origin/$env:GITHUB_BASE_REF; refs/remotes/origin/HEAD; origin/main.
    With none, the diff is against HEAD and a warning says so.

.PARAMETER Base
    Base ref or sha to diff against.

.PARAMETER Json
    Emit {tags, cases, estUsd, command, warnings} as JSON.

.PARAMETER Root
    Repo root. Defaults to two levels up from this script.

.PARAMETER BashPath
    Path to the bash that --scaffold would use. Defaults to the first bash on PATH (tests).

.EXAMPLE
    .\scripts\ticket\Select-EvalCases.ps1
#>

[CmdletBinding()]
param(
    [string]$Base,
    [switch]$Json,
    [string]$Root = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [string]$BashPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RunsPerCase = 3
$UsdPerRun = 0.30
$warnings = [System.Collections.Generic.List[string]]::new()

function Invoke-Git {
    param([string[]]$GitArgs)
    $out = @(& git -C $Root @GitArgs 2>$null)
    return [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Lines = $out }
}

function Test-AnyGlob([string]$Path, $Globs) {
    foreach ($g in @($Globs)) { if ($g -and $Path -like $g) { return $true } }
    return $false
}

function Get-CaseTags {
    param([string]$File)
    foreach ($line in (Get-Content -LiteralPath $File -TotalCount 40)) {
        if ($line -match '^tags:\s*\[(.*)\]\s*$') {
            return @($Matches[1] -split ',' | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ })
        }
    }
    return @()
}

# ---- cases on disk ---------------------------------------------------------
$evalsDir = Join-Path $Root 'evals'
$cases = @()
if (Test-Path -LiteralPath $evalsDir) {
    foreach ($dir in (Get-ChildItem -LiteralPath $evalsDir -Directory | Sort-Object Name)) {
        $yaml = Join-Path $dir.FullName 'case.yaml'
        $prompt = Join-Path $dir.FullName 'prompt.md'
        $file = if (Test-Path -LiteralPath $yaml) { $yaml } elseif (Test-Path -LiteralPath $prompt) { $prompt } else { $null }
        if (-not $file) { continue }
        $scaffold = ($file -eq $yaml) -and [bool](Select-String -LiteralPath $yaml -Pattern '^\s*scaffold_script:' -Quiet)
        $cases += [pscustomobject]@{ Name = $dir.Name; Tags = @(Get-CaseTags $file); Scaffold = $scaffold }
    }
}

# ---- base and changed set ---------------------------------------------------
$changed = [System.Collections.Generic.HashSet[string]]::new()
$baseLabel = 'HEAD'
if (-not (Get-Command git -ErrorAction SilentlyContinue) -or -not (Invoke-Git @('rev-parse', '--is-inside-work-tree')).Ok) {
    $warnings.Add('not a git work tree; nothing to diff')
}
else {
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($Base) { $candidates.Add($Base) }
    if ($env:DOCSYNC_BASE -and $env:DOCSYNC_BASE -notmatch '^0+$') { $candidates.Add($env:DOCSYNC_BASE) }
    if ($env:GITHUB_BASE_REF) { $candidates.Add("origin/$($env:GITHUB_BASE_REF)") }
    $originHead = Invoke-Git @('symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD')
    if ($originHead.Ok -and $originHead.Lines.Count) { $candidates.Add(($originHead.Lines[0] -replace '^refs/remotes/', '')) }
    $candidates.Add('origin/main')

    $baseRef = $null
    foreach ($c in $candidates) {
        if ((Invoke-Git @('rev-parse', '--verify', '--quiet', "$c^{commit}")).Ok) { $baseRef = $c; break }
    }
    $mb = 'HEAD'
    if ($baseRef) {
        $mbResult = Invoke-Git @('merge-base', $baseRef, 'HEAD')
        if ($mbResult.Ok -and $mbResult.Lines.Count) { $mb = $mbResult.Lines[0].Trim(); $baseLabel = $baseRef }
        else { $warnings.Add("no merge-base between $baseRef and HEAD; diffing against HEAD") }
    }
    else { $warnings.Add("no base ref resolves (tried: $($candidates -join ', ')); diffing against HEAD") }

    foreach ($line in (Invoke-Git @('diff', '--name-only', $mb)).Lines) { [void]$changed.Add(($line -replace '\\', '/').Trim()) }
    foreach ($line in (Invoke-Git @('ls-files', '--others', '--exclude-standard')).Lines) { [void]$changed.Add(($line -replace '\\', '/').Trim()) }
    [void]$changed.Remove('')
}

# ---- changed files -> tags ---------------------------------------------------
$mapPath = Join-Path $evalsDir 'case-map.psd1'
$rules = @()
if (Test-Path -LiteralPath $mapPath) { $rules = @((Import-PowerShellDataFile -LiteralPath $mapPath).Rules) }
else { $warnings.Add('evals/case-map.psd1 not found') }

$tags = [System.Collections.Generic.SortedSet[string]]::new()
foreach ($file in $changed) {
    foreach ($rule in $rules) {
        if (Test-AnyGlob $file $rule.When) { foreach ($t in @($rule.Tags)) { [void]$tags.Add($t) } }
    }
    if ($file -match '^evals/([^/]+)/') {
        $own = $cases | Where-Object { $_.Name -eq $Matches[1] }
        foreach ($c in @($own)) { foreach ($t in $c.Tags) { [void]$tags.Add($t) } }
    }
}

$selected = @($cases | Where-Object { $c = $_; @($c.Tags | Where-Object { $tags.Contains($_) }).Count -gt 0 })
$tagList = @($tags)

$estUsd = [math]::Round($selected.Count * $RunsPerCase * $UsdPerRun, 2)
$command = $null
if ($selected.Count) {
    $maxCost = [int][math]::Ceiling($estUsd * 1.5)
    $command = 'claude plugin eval . --eval-dir evals --trust-plugin --ablation none --allow-tools Write Edit --scaffold --keep-temp --no-publish --threshold 1.0 --model sonnet' +
        " --max-cost-usd $maxCost " + (($tagList | ForEach-Object { "--tag $_" }) -join ' ') + ' --json tmp/eval.json'
}

# ---- Windows bash stub -------------------------------------------------------
$bashFix = '$env:PATH = "C:\Program Files\Git\bin;$env:PATH"'
if (@($selected | Where-Object { $_.Scaffold }).Count) {
    $bash = if ($BashPath) { $BashPath } else { (Get-Command bash -ErrorAction SilentlyContinue).Source }
    if ($bash -and (($bash -replace '/', '\') -like '*\Microsoft\WindowsApps\*')) {
        $warnings.Add("bash resolves to the WindowsApps stub ($bash); it strips backslashes from the scaffold path and the seeded cases score 0. Fix: $bashFix")
    }
}

if ($Json) {
    [pscustomobject]@{
        tags     = $tagList
        cases    = @($selected | ForEach-Object { $_.Name })
        estUsd   = $estUsd
        command  = $command
        warnings = @($warnings)
    } | ConvertTo-Json -Depth 4
    exit 0
}

foreach ($w in $warnings) { Write-Output "[WARN] $w" }
if (-not $selected.Count) {
    Write-Output "[INFO] no eval needed ($($changed.Count) changed file(s) vs $baseLabel map to no eval tag)"
    exit 0
}
Write-Output "[INFO] $($changed.Count) changed file(s) vs $baseLabel"
Write-Output ("Tags:  " + ($tagList -join ', '))
Write-Output ("Cases ($($selected.Count)): " + (($selected | ForEach-Object { $_.Name }) -join ', '))
Write-Output ('Est. cost: ${0:N2} ({1} cases x {2} runs x ${3:N2})' -f $estUsd, $selected.Count, $RunsPerCase, $UsdPerRun)
Write-Output 'Run:'
Write-Output $command
exit 0
