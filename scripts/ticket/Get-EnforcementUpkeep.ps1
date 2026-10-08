#Requires -Version 7
<#
.SYNOPSIS
    Reports how the enforcement layer is being used: Docs-Unaffected waivers, doc-claims
    registry size, and swallowed hook errors. Report only; it never fails and never prunes.

.DESCRIPTION
    Three signals, so waivers cannot pile up unseen and a claim can be retired once a check
    covers its fact:
      waivers      commits since -Days carrying a Docs-Unaffected trailer, per rule, with
                   thin reasons (under 15 characters) flagged
      claims       count of Claims and CoChange rules in scripts/ticket/doc-claims.psd1
      hook errors  lines in scripts/.hook-errors.log, per hook, with the latest timestamp

.PARAMETER Root
    Repo root. Defaults to two levels up from this script.

.PARAMETER Days
    Look-back window for waivers and hook errors. Default 30.

.PARAMETER HookErrorsLog
    Hook error log. Defaults to scripts/.hook-errors.log under Root.

.EXAMPLE
    .\scripts\ticket\Get-EnforcementUpkeep.ps1 -Days 90
#>

[CmdletBinding()]
param(
    [string]$Root = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [ValidateRange(1, 3650)][int]$Days = 30,
    [string]$HookErrorsLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $HookErrorsLog) { $HookErrorsLog = Join-Path $Root 'scripts/.hook-errors.log' }
$since = (Get-Date).AddDays(-$Days)

# ---- waivers -----------------------------------------------------------------
$waivers = @()
if (Test-Path -LiteralPath (Join-Path $Root '.git')) {
    $raw = & git -C $Root log "--since=$($since.ToString('yyyy-MM-dd'))" --grep=Docs-Unaffected `
        '--format=%h%x1f%(trailers:key=Docs-Unaffected,valueonly,separator=%x1e)' 2>$null
    foreach ($line in @($raw)) {
        if (-not $line) { continue }
        $parts = $line -split [char]0x1f, 2
        if ($parts.Count -lt 2) { continue }
        foreach ($v in ($parts[1] -split [char]0x1e)) {
            $t = $v.Trim()
            if (-not $t) { continue }
            $m = [regex]::Match($t, '^([a-z0-9-]+):\s*(.*)$')
            $rule = if ($m.Success) { $m.Groups[1].Value } else { '(all rules)' }
            $reason = if ($m.Success) { $m.Groups[2].Value.Trim() } else { $t }
            $waivers += [pscustomobject]@{ Sha = $parts[0]; Rule = $rule; Thin = ($reason.Length -lt 15) }
        }
    }
}
Write-Output "[INFO] upkeep waivers: $($waivers.Count) in the last $Days day(s)"
foreach ($g in ($waivers | Group-Object Rule | Sort-Object Count -Descending)) {
    $thin = @($g.Group | Where-Object Thin).Count
    $note = if ($thin) { ", $thin thin reason(s)" } else { '' }
    Write-Output "[INFO]   $($g.Name): $($g.Count)$note"
}

# ---- registry size -------------------------------------------------------------
$registry = Join-Path $Root 'scripts/ticket/doc-claims.psd1'
if (Test-Path -LiteralPath $registry) {
    $data = Import-PowerShellDataFile -LiteralPath $registry
    Write-Output "[INFO] upkeep claims: $(@($data.Claims).Count) claim(s), $(@($data.CoChange).Count) co-change rule(s); retire a claim once a check covers its fact"
} else {
    Write-Output '[INFO] upkeep claims: doc-claims.psd1 not found'
}

# ---- hook errors ---------------------------------------------------------------
$errors = @()
if (Test-Path -LiteralPath $HookErrorsLog) {
    foreach ($line in (Get-Content -LiteralPath $HookErrorsLog)) {
        if (-not $line.Trim()) { continue }
        try { $e = $line | ConvertFrom-Json } catch { continue }
        $at = [datetime]::MinValue
        if (-not [datetime]::TryParse([string]$e.at, [ref]$at)) { continue }
        if ($at.ToUniversalTime() -ge $since.ToUniversalTime()) { $errors += [pscustomobject]@{ Hook = [string]$e.hook; At = $at } }
    }
}
Write-Output "[INFO] upkeep hook errors: $($errors.Count) in the last $Days day(s)"
foreach ($g in ($errors | Group-Object Hook | Sort-Object Count -Descending)) {
    $last = ($g.Group | Sort-Object At -Descending | Select-Object -First 1).At.ToString('yyyy-MM-dd')
    Write-Output "[INFO]   $($g.Name): $($g.Count), latest $last"
}
exit 0
