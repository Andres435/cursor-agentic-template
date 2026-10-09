#Requires -Version 7
#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for Invoke-ExternalLane.ps1 with inline fake CLIs (pwsh -NoProfile
    -Command ...), so no script file is written outside the repo.
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'Invoke-ExternalLane.ps1'
    $script:PwshHost = (Get-Command pwsh).Source
    $script:Utf8 = New-Object System.Text.UTF8Encoding($false)
    $script:Prompt = Join-Path $TestDrive 'prompt.md'
    [System.IO.File]::WriteAllText($script:Prompt, 'design this thing', $script:Utf8)

    # A config with one entry whose "CLI" is an inline pwsh command.
    function New-Config {
        param([string]$Command, [bool]$ReadOnly = $true, [string]$Family = 'gpt', [int]$TimeoutSec = 30, [string]$Name = 'fake')
        $path = Join-Path $TestDrive ('cfg-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.json')
        $entry = [ordered]@{
            name = $Name; family = $Family; readOnly = $ReadOnly; timeoutSec = $TimeoutSec
            command = @('pwsh', '-NoProfile', '-Command', $Command)
        }
        [System.IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject @($entry) -Depth 4), $script:Utf8)
        return $path
    }

    function Invoke-Lane {
        param([string]$Config, [string]$Name = 'fake')
        $out = & $script:PwshHost -NoProfile -NonInteractive -File $script:ScriptPath -Name $Name -PromptFile $script:Prompt -ConfigPath $Config -Json 2>&1
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Result = (($out -join "`n") | ConvertFrom-Json) }
    }
}

Describe 'Invoke-ExternalLane' {
    It 'returns ok with the model and the body, and the prompt reaches stdin' {
        $cfg = New-Config -Command '$in = [Console]::In.ReadToEnd(); "model: GPT-fake-1"; "";  "got: " + $in.Substring(0, 6)'
        $r = Invoke-Lane $cfg
        $r.ExitCode | Should -Be 0
        $r.Result.status | Should -Be 'ok'
        $r.Result.model | Should -Be 'GPT-fake-1'
        $r.Result.output | Should -Be 'got: design'
    }

    It 'drops out a reply from the wrong family' {
        $r = Invoke-Lane (New-Config -Command '$null = [Console]::In.ReadToEnd(); "model: claude-x"; "body"')
        $r.ExitCode | Should -Be 0
        $r.Result.status | Should -Be 'dropout'
        $r.Result.reason | Should -Match 'not family'
        $r.Result.output | Should -BeNullOrEmpty
    }

    It 'drops out a reply with no model line' {
        $r = Invoke-Lane (New-Config -Command '$null = [Console]::In.ReadToEnd(); "just an answer"')
        $r.Result.status | Should -Be 'dropout'
        $r.Result.reason | Should -Match "not 'model:"
    }

    It 'drops out on a non-zero exit' {
        $r = Invoke-Lane (New-Config -Command '$null = [Console]::In.ReadToEnd(); "model: gpt-x"; exit 3')
        $r.ExitCode | Should -Be 0
        $r.Result.status | Should -Be 'dropout'
        $r.Result.reason | Should -Match 'exited 3'
    }

    It 'drops out on timeout and does not wait for the process' {
        $cfg = New-Config -Command 'Start-Sleep 20; "model: gpt-x"' -TimeoutSec 1
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $r = Invoke-Lane $cfg
        $watch.Stop()
        $r.Result.status | Should -Be 'dropout'
        $r.Result.reason | Should -Match 'timed out'
        $watch.Elapsed.TotalSeconds | Should -BeLessThan 15
    }

    It 'drops out when the executable is missing' {
        $path = Join-Path $TestDrive 'missing-exe.json'
        [System.IO.File]::WriteAllText($path, '[{"name":"fake","family":"gpt","readOnly":true,"command":["no-such-cli-xyz","-"]}]', $script:Utf8)
        $r = Invoke-Lane $path
        $r.Result.status | Should -Be 'dropout'
        $r.Result.reason | Should -Match 'not found'
    }

    It 'refuses an entry that is not readOnly:true' {
        $r = Invoke-Lane (New-Config -Command '"model: gpt-x"' -ReadOnly $false)
        $r.ExitCode | Should -Be 1
        $r.Result.status | Should -Be 'refused'
    }

    It 'drops out as not configured when there is no config or no such entry' {
        $none = Invoke-Lane (Join-Path $TestDrive 'does-not-exist.json')
        $none.ExitCode | Should -Be 0
        $none.Result.status | Should -Be 'dropout'
        $none.Result.reason | Should -Be 'not configured'
        $other = Invoke-Lane (New-Config -Command '"model: gpt-x"') -Name 'other'
        $other.Result.reason | Should -Be 'not configured'
    }

    It '-List prints the configured names and runs nothing' {
        $cfg = New-Config -Command '"model: gpt-x"'
        $out = & $script:PwshHost -NoProfile -NonInteractive -File $script:ScriptPath -List -ConfigPath $cfg
        ($out -join '') | ConvertFrom-Json | Should -Be @('fake')
    }
}
