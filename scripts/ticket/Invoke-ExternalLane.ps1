#Requires -Version 7
<#
.SYNOPSIS
    Run one opt-in external read-only lane (another vendor's CLI) with a prompt file and
    return its output, or a dropout when it cannot be trusted.

.DESCRIPTION
    Reads user/external-lanes.local.json (user-local, gitignored): an array of
    { name, family, command (argv array), readOnly (bool), timeoutSec (int, default 600) }.
    user/external-lanes.example.json shows the shape.

    Runs argv[0] with the remaining arguments through System.Diagnostics.Process (no shell
    string), sends the prompt file on stdin, captures stdout and stderr, and kills the process
    tree when timeoutSec passes. The prompt gets a one-line trailer asking for a first line
    `model: <model>`. The reply is accepted only when its first non-empty line is exactly
    `model: <x>` and <x> starts with the entry's family (case-insensitive). Anything else
    (not configured, missing executable, timeout, non-zero exit, no or wrong model line) is
    status "dropout" with a reason, exit 0: the caller reports one line and moves on. An entry
    without readOnly:true is "refused" (exit 1). Another model is never substituted.

    -List prints the configured entry names (JSON array) and runs nothing.

.PARAMETER Name
    Entry name in the config.

.PARAMETER PromptFile
    File whose text is sent on stdin.

.PARAMETER ConfigPath
    Config location. Defaults to user/external-lanes.local.json under the repo root.

.PARAMETER Json
    Emit {status, reason, name, model, output} as JSON.

.PARAMETER List
    List configured entry names and exit.

.EXAMPLE
    .\scripts\ticket\Invoke-ExternalLane.ps1 -Name codex -PromptFile tmp\design-prompt.md -Json
#>

[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$Name,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$PromptFile,
    [string]$ConfigPath = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'user/external-lanes.local.json'),
    [switch]$Json,
    [Parameter(Mandatory, ParameterSetName = 'List')][switch]$List
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Entries {
    if (-not (Test-Path -LiteralPath $ConfigPath)) { return $null }
    try {
        $data = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch { return @{ Error = "config unreadable: $($_.Exception.Message)" } }
    return ,@($data | Where-Object { $_ -is [pscustomobject] -and $_.PSObject.Properties.Name -contains 'name' })
}

function Get-Prop($Obj, [string]$Prop, $Default = $null) {
    if ($Obj.PSObject.Properties.Name -contains $Prop -and $null -ne $Obj.$Prop) { return $Obj.$Prop }
    return $Default
}

function Write-Result {
    param([string]$Status, [string]$Reason = '', [string]$Model = '', [string]$Output = '')
    if ($Json) {
        [pscustomobject]@{ status = $Status; reason = $Reason; name = $Name; model = $Model; output = $Output } | ConvertTo-Json -Depth 3
    }
    else {
        switch ($Status) {
            'ok' { Write-Output "[OK] external lane '$Name' ran on $Model"; if ($Output) { Write-Output $Output } }
            'dropout' { Write-Output "[DROPOUT] external lane '$Name': $Reason" }
            default { Write-Output "[REFUSED] external lane '$Name': $Reason" }
        }
    }
    if ($Status -eq 'refused') { exit 1 }
    exit 0
}

$entries = Read-Entries

if ($List) {
    $names = if ($entries -and $entries -isnot [hashtable]) { @($entries | ForEach-Object { [string]$_.name }) } else { @() }
    ConvertTo-Json -InputObject @($names) -Compress
    exit 0
}

if ($null -eq $entries) { Write-Result -Status 'dropout' -Reason 'not configured' }
if ($entries -is [hashtable]) { Write-Result -Status 'dropout' -Reason $entries.Error }
$entry = @($entries | Where-Object { $_.name -eq $Name }) | Select-Object -First 1
if (-not $entry) { Write-Result -Status 'dropout' -Reason 'not configured' }

if ((Get-Prop $entry 'readOnly' $false) -ne $true) {
    Write-Result -Status 'refused' -Reason 'entry is not marked readOnly:true; an external lane must be read-only'
}
$family = [string](Get-Prop $entry 'family' '')
$argv = @(Get-Prop $entry 'command' @() | ForEach-Object { [string]$_ })
if (-not $family) { Write-Result -Status 'dropout' -Reason 'entry has no family' }
if (-not $argv.Count) { Write-Result -Status 'dropout' -Reason 'entry has no command' }
$timeoutSec = [int](Get-Prop $entry 'timeoutSec' 600)

if (-not (Test-Path -LiteralPath $PromptFile)) { throw "Prompt file not found: $PromptFile" }
$prompt = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $PromptFile).Path) +
    "`n`nFirst line of your reply must be ``model: <the model you are running on>``.`n"

$exe = Get-Command -Name $argv[0] -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $exe) { Write-Result -Status 'dropout' -Reason "executable '$($argv[0])' not found" }

$psi = [System.Diagnostics.ProcessStartInfo]::new($exe.Source)
foreach ($a in @($argv | Select-Object -Skip 1)) { $psi.ArgumentList.Add($a) }
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
$psi.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)

try { $proc = [System.Diagnostics.Process]::Start($psi) }
catch { Write-Result -Status 'dropout' -Reason "could not start '$($argv[0])': $($_.Exception.Message)" }

$stdoutTask = $proc.StandardOutput.ReadToEndAsync()
$stderrTask = $proc.StandardError.ReadToEndAsync()
try {
    $proc.StandardInput.Write($prompt)
    $proc.StandardInput.Close()
}
catch { }   # the CLI may exit before reading all of stdin; its exit code decides

if (-not $proc.WaitForExit($timeoutSec * 1000)) {
    try { $proc.Kill($true) } catch { }
    Write-Result -Status 'dropout' -Reason "timed out after $timeoutSec s"
}
$proc.WaitForExit()
$stdout = $stdoutTask.GetAwaiter().GetResult()
$stderr = $stderrTask.GetAwaiter().GetResult()

if ($proc.ExitCode -ne 0) {
    $why = (($stderr -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -First 1)
    Write-Result -Status 'dropout' -Reason "exited $($proc.ExitCode)$(if ($why) { ': ' + $why.Trim() })"
}

$lines = @($stdout -split "`r?`n")
$first = 0
while ($first -lt $lines.Count -and -not $lines[$first].Trim()) { $first++ }
if ($first -ge $lines.Count) { Write-Result -Status 'dropout' -Reason 'empty reply (no model line)' }
$m = [regex]::Match($lines[$first].Trim(), '^model:\s+(\S.*)$')
if (-not $m.Success) { Write-Result -Status 'dropout' -Reason "first line is not 'model: <x>' (got '$($lines[$first].Trim())')" }
$model = $m.Groups[1].Value.Trim()
if (-not $model.StartsWith($family, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Result -Status 'dropout' -Reason "model '$model' is not family '$family'; discarded"
}
$body = (($lines | Select-Object -Skip ($first + 1)) -join "`n").Trim()
Write-Result -Status 'ok' -Model $model -Output $body
