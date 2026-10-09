#Requires -Version 7
#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for Select-EvalCases.ps1: changed files map to eval tags and cases,
    the cost and command are derived, and the Windows bash stub is flagged.

.DESCRIPTION
    Each test builds a throwaway git repo under $TestDrive holding only data files
    (no scripts), commits it on a base branch, then edits files uncommitted.
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'Select-EvalCases.ps1'
    $script:RealMap = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'evals/case-map.psd1'
    $script:PwshHost = (Get-Command pwsh).Source
    $script:Utf8 = New-Object System.Text.UTF8Encoding($false)

    function Write-Data([string]$Root, [string]$Rel, [string]$Text) {
        $path = Join-Path $Root $Rel
        New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
        [System.IO.File]::WriteAllText($path, $Text, $script:Utf8)
    }

    # A committed repo with two prompt cases and two scaffolded case.yaml cases; branch 'base' marks the commit.
    function New-EvalRepo {
        $root = Join-Path $TestDrive ('repo-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Copy-Item -LiteralPath $script:RealMap -Destination (New-Item -ItemType Directory -Path (Join-Path $root 'evals') -Force).FullName
        Write-Data $root 'evals/start-bug/prompt.md' "---`ndescription: x`ntags: [start-ticket, plan-artifacts, bug]`nruns: 3`n---`nbody"
        Write-Data $root 'evals/refuse-migration/prompt.md' "---`ntags: [start-ticket, policy, refusal]`n---`nbody"
        Write-Data $root 'evals/close-bug/case.yaml' "name: close-bug`ntags: [complete-task, close, bug]`nruns: 3`ncontext:`n  scaffold_script: scaffold.sh`n"
        Write-Data $root 'evals/review-security/case.yaml' "name: review-security`ntags: [review, security, policy]`nruns: 3`ncontext:`n  scaffold_script: scaffold.sh`n"
        Write-Data $root 'skills/review-changes/SKILL.md' 'one'
        Write-Data $root 'scripts/ticket/manifest.schema.json' '{}'
        Write-Data $root 'README.md' 'docs'
        & git -C $root init -q -b main 2>&1 | Out-Null
        & git -C $root add -A 2>&1 | Out-Null
        & git -C $root -c user.name=t -c user.email=t@t commit -q -m base 2>&1 | Out-Null
        return $root
    }

    function Invoke-Select {
        param([string]$Root, [string]$BashPath = 'C:\Program Files\Git\bin\bash.exe')
        $out = & $script:PwshHost -NoProfile -NonInteractive -File $script:ScriptPath -Root $Root -Base main -Json -BashPath $BashPath 2>&1
        return ($out -join "`n") | ConvertFrom-Json
    }
}

Describe 'Select-EvalCases' {
    It 'maps a skills/review-changes edit to the review tag and the review case' {
        $root = New-EvalRepo
        Write-Data $root 'skills/review-changes/SKILL.md' 'two'
        $r = Invoke-Select -Root $root
        $r.tags | Should -Be @('review')
        $r.cases | Should -Be @('review-security')
        $r.estUsd | Should -Be 0.9
        $r.command | Should -Match '--tag review'
        $r.command | Should -Match '--max-cost-usd 2 '
        $r.command | Should -Match '--json tmp/eval.json$'
    }

    It 'maps a manifest.schema.json edit to start-ticket and complete-task cases' {
        $root = New-EvalRepo
        Write-Data $root 'scripts/ticket/manifest.schema.json' '{"a":1}'
        $r = Invoke-Select -Root $root
        $r.tags | Should -Be @('complete-task', 'start-ticket')
        $r.cases | Should -Be @('close-bug', 'refuse-migration', 'start-bug')
        $r.estUsd | Should -Be 2.7
        $r.command | Should -Match '--tag complete-task --tag start-ticket'
    }

    It 'maps an edit under evals/<case>/ to that case''s own tags' {
        $root = New-EvalRepo
        Write-Data $root 'evals/review-security/extra.txt' 'x'
        $r = Invoke-Select -Root $root
        $r.tags | Should -Be @('policy', 'review', 'security')
        $r.cases | Should -Contain 'review-security'
        $r.cases | Should -Contain 'refuse-migration'
    }

    It 'prints no eval needed for a docs-only edit' {
        $root = New-EvalRepo
        Write-Data $root 'README.md' 'changed docs'
        $r = Invoke-Select -Root $root
        @($r.cases).Count | Should -Be 0
        $r.command | Should -BeNullOrEmpty
        $plain = & $script:PwshHost -NoProfile -NonInteractive -File $script:ScriptPath -Root $root -Base main 2>&1 | Out-String
        $plain | Should -Match '\[INFO\] no eval needed'
    }

    It 'warns when a scaffolded case is selected and bash is the WindowsApps stub' {
        $root = New-EvalRepo
        Write-Data $root 'skills/review-changes/SKILL.md' 'two'
        $r = Invoke-Select -Root $root -BashPath 'C:\Users\x\AppData\Local\Microsoft\WindowsApps\bash.exe'
        ($r.warnings -join "`n") | Should -Match 'WindowsApps stub'
        ($r.warnings -join "`n") | Should -Match ([regex]::Escape('C:\Program Files\Git\bin'))
    }

    It 'does not warn with Git bash, or when no selected case needs a scaffold' {
        $root = New-EvalRepo
        Write-Data $root 'skills/review-changes/SKILL.md' 'two'
        @((Invoke-Select -Root $root).warnings).Count | Should -Be 0
        $root2 = New-EvalRepo
        Write-Data $root2 'evals/start-bug/prompt.md' "---`ntags: [plan-artifacts]`n---`nbody"
        $r = Invoke-Select -Root $root2 -BashPath 'C:\Users\x\AppData\Local\Microsoft\WindowsApps\bash.exe'
        $r.cases | Should -Not -Contain 'close-bug'
        @($r.warnings).Count | Should -Be 0
    }
}
