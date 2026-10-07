#Requires -Version 7
<#
.SYNOPSIS
    Fails a branch that changes a gate, hook, or lifecycle skill without touching the docs
    that describe it, unless a commit says why no doc needed to change.

.DESCRIPTION
    Reads the CoChange rules in scripts/ticket/doc-claims.psd1. For each rule, if any
    changed file matches When (minus Ignore), at least one changed file must match Touch.
    Otherwise a commit in the branch must carry the trailer

        Docs-Unaffected: <ruleId>: <reason>      (one rule)
        Docs-Unaffected: <reason>                (every rule)

    with a reason of at least 15 characters that is not "n/a" or "none". Each waiver is
    printed as an [INFO] line, so CI logs keep the audit trail. Query past waivers with:

        git log --format='%h %s%n  %(trailers:key=Docs-Unaffected,valueonly)' --grep=Docs-Unaffected

    This is the second line of defense. A co-change can be satisfied by touching a doc
    without fixing it; the claims in the same registry (Assert-AgenticFlow 12b) check what
    the docs say. The changed set is the branch since its merge-base, plus uncommitted and
    untracked files, so a violation is caught before the push.

    Base ref, first that resolves: -Base; $env:DOCSYNC_BASE (CI push: github.event.before,
    all zeros = new branch, skipped); origin/$env:GITHUB_BASE_REF (CI pull_request);
    refs/remotes/origin/HEAD; origin/main. With no git or no base it prints [INFO] and
    passes -- except under GITHUB_ACTIONS, where a missing base fails, so a shallow
    checkout cannot quietly turn the check off.

.PARAMETER Root
    Repo root. Defaults to two levels up from this script.

.PARAMETER Base
    Base ref or sha to diff against (overrides the environment).

.EXAMPLE
    .\scripts\ticket\Assert-DocSync.ps1

.EXAMPLE
    .\scripts\ticket\Assert-DocSync.ps1 -Base origin/main
#>

[CmdletBinding()]
param(
    [string]$Root = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [string]$Base
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$inCi = $env:GITHUB_ACTIONS -eq 'true'

function Skip([string]$Why) {
    if ($inCi) {
        Write-Output "[FAIL] doc-sync: $Why (CI must have a base to compare against; check fetch-depth: 0)"
        exit 1
    }
    Write-Output "[INFO] doc-sync skipped: $Why"
    exit 0
}

function Invoke-Git {
    param([string[]]$GitArgs)
    $out = @(& git -C $Root @GitArgs 2>$null)
    return [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Lines = $out }
}

function Test-AnyGlob([string]$Path, $Globs) {
    foreach ($g in @($Globs)) { if ($g -and $Path -like $g) { return $true } }
    return $false
}

$registryPath = Join-Path $Root 'scripts/ticket/doc-claims.psd1'
if (-not (Test-Path -LiteralPath $registryPath)) {
    Write-Output "[FAIL] doc-sync: scripts/ticket/doc-claims.psd1 not found"
    exit 1
}
$registry = Import-PowerShellDataFile -LiteralPath $registryPath
$rules = @(if ($registry.ContainsKey('CoChange')) { $registry.CoChange })
if (-not $rules.Count) { Write-Output "[INFO] doc-sync: no CoChange rules"; exit 0 }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Skip 'git is not on PATH' }
if (-not (Invoke-Git @('rev-parse', '--is-inside-work-tree')).Ok) { Skip 'not a git work tree' }

# ---- base ------------------------------------------------------------------
$candidates = [System.Collections.Generic.List[string]]::new()
if ($Base) { $candidates.Add($Base) }
if ($env:DOCSYNC_BASE) {
    if ($env:DOCSYNC_BASE -match '^0+$') { Write-Output "[INFO] doc-sync skipped: new branch push (no previous commit)"; exit 0 }
    $candidates.Add($env:DOCSYNC_BASE)
}
if ($env:GITHUB_BASE_REF) { $candidates.Add("origin/$($env:GITHUB_BASE_REF)") }
$originHead = Invoke-Git @('symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD')
if ($originHead.Ok -and $originHead.Lines.Count) { $candidates.Add(($originHead.Lines[0] -replace '^refs/remotes/', '')) }
$candidates.Add('origin/main')

$baseRef = $null
foreach ($c in $candidates) {
    if ((Invoke-Git @('rev-parse', '--verify', '--quiet', "$c^{commit}")).Ok) { $baseRef = $c; break }
}
if (-not $baseRef) { Skip "no base ref resolves (tried: $($candidates -join ', '))" }
$mbResult = Invoke-Git @('merge-base', $baseRef, 'HEAD')
if (-not $mbResult.Ok -or -not $mbResult.Lines.Count) { Skip "no merge-base between $baseRef and HEAD" }
$mb = $mbResult.Lines[0].Trim()

# ---- changed files ---------------------------------------------------------
$changed = [System.Collections.Generic.HashSet[string]]::new()
foreach ($line in (Invoke-Git @('diff', '--name-only', $mb)).Lines) { [void]$changed.Add(($line -replace '\\', '/').Trim()) }
foreach ($line in (Invoke-Git @('ls-files', '--others', '--exclude-standard')).Lines) { [void]$changed.Add(($line -replace '\\', '/').Trim()) }
$changed.Remove('') | Out-Null

# ---- waivers from commit trailers --------------------------------------------
# One line per commit: <sha>\x1f<value>\x1f<value>...
$waivers = [System.Collections.Generic.List[object]]::new()
$log = Invoke-Git @('log', '--format=%h%x1f%(trailers:key=Docs-Unaffected,valueonly,separator=%x1f)', "$mb..HEAD")
foreach ($line in $log.Lines) {
    $parts = @($line -split [char]0x1f)
    $sha = $parts[0]
    foreach ($value in @($parts | Select-Object -Skip 1)) {
        $v = $value.Trim()
        if (-not $v) { continue }
        $ruleId = $null
        $reason = $v
        $m = [regex]::Match($v, '^([a-z0-9-]+):\s*(.*)$')
        if ($m.Success -and (@($rules | ForEach-Object { $_.Id }) -contains $m.Groups[1].Value)) {
            $ruleId = $m.Groups[1].Value
            $reason = $m.Groups[2].Value.Trim()
        }
        $valid = ($reason.Length -ge 15) -and ($reason -notmatch '^(?i)(n/?a|none|no|-+|tbd)\.?$')
        $waivers.Add([pscustomobject]@{ Sha = $sha; Rule = $ruleId; Reason = $reason; Valid = $valid })
    }
}

# ---- rules -------------------------------------------------------------------
$failures = 0
foreach ($rule in $rules) {
    $ignore = if ($rule.ContainsKey('Ignore')) { $rule.Ignore } else { @() }
    $hits = @($changed | Where-Object { (Test-AnyGlob $_ $rule.When) -and -not (Test-AnyGlob $_ $ignore) } | Sort-Object)
    if (-not $hits.Count) { continue }
    $touched = @($changed | Where-Object { Test-AnyGlob $_ $rule.Touch })
    if ($touched.Count) { continue }

    $applicable = @($waivers | Where-Object { -not $_.Rule -or $_.Rule -eq $rule.Id })
    $good = @($applicable | Where-Object { $_.Valid })
    if ($good.Count) {
        foreach ($w in $good) { Write-Output "[INFO] doc-sync waived $($w.Sha) $($rule.Id): $($w.Reason)" }
        continue
    }
    $failures++
    $shown = ($hits | Select-Object -First 5) -join ', '
    if ($hits.Count -gt 5) { $shown += ", +$($hits.Count - 5) more" }
    $bad = @($applicable | Where-Object { -not $_.Valid })
    $why = if ($bad.Count) { " A Docs-Unaffected trailer was found but its reason is too thin ('$($bad[0].Reason)')." } else { '' }
    Write-Output ("[FAIL] doc-sync: $($rule.Id) -- $shown changed, but none of $($rule.Touch -join ' | ') did.$why " +
        "Update the doc that describes it, or add a commit trailer 'Docs-Unaffected: $($rule.Id): <why no doc changes>'. ($($rule.Why))")
}

if ($failures) { exit 1 }
Write-Output "[PASS] doc-sync: $($rules.Count) rule(s) checked against $baseRef ($($changed.Count) changed file(s))."
exit 0
