#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for the Assert-AgenticFlow checks that need a fixture tree:
    index-coverage (every doc has an INDEX.md row) and worktype-templates (every
    router workType maps to a plan template that exists). Other checks fail on a bare
    fixture, so each test asserts only on its own check's lines.
#>

BeforeAll {
    $script:Gate = Join-Path $PSScriptRoot 'Assert-AgenticFlow.ps1'

    function New-FlowRoot([string]$Name) {
        $root = Join-Path $TestDrive $Name
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        & git -C $root init -q
        return $root
    }
    function Write-Doc([string]$Root, [string]$Rel, [string]$Text) {
        $path = Join-Path $Root $Rel
        New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
        Set-Content -LiteralPath $path -Value $Text -Encoding UTF8
    }
    function Invoke-Gate([string]$Root) {
        $out = & pwsh -NoProfile -File $script:Gate -Root $Root 2>&1 | Out-String
        return $out
    }
}

AfterAll {
    Get-ChildItem -LiteralPath $TestDrive -Recurse -Force -File | ForEach-Object { $_.IsReadOnly = $false }
}

Describe 'Assert-AgenticFlow index-coverage' {
    It 'names a doc with no INDEX row, and accepts linked, grouped, and exempt docs' {
        $root = New-FlowRoot 'index'
        Write-Doc $root 'INDEX.md' "| [skills/a/SKILL.md](skills/a/SKILL.md) | a |`n| Rules: [rules/x.mdc](rules/x.mdc), [rules/y.mdc](rules/y.mdc#top) | grouped |"
        Write-Doc $root 'skills/a/SKILL.md' 'a'
        Write-Doc $root 'skills/b/SKILL.md' 'b'
        Write-Doc $root 'rules/x.mdc' 'x'
        Write-Doc $root 'rules/y.mdc' 'y'
        Write-Doc $root 'plans/TICKET-00001-bug-plan.md' 'ticket plan'
        Write-Doc $root 'scripts/ticket/fixtures/plans/TICKET-00001-feature-plan.md' 'fixture'
        Write-Doc $root 'skills/b/README.md' 'folder readme'
        $out = Invoke-Gate $root
        $out | Should -Match 'index-coverage: INDEX.md has no row linking skills/b/SKILL.md'
        $out | Should -Not -Match 'linking skills/a/SKILL.md'
        $out | Should -Not -Match 'linking rules/'
        $out | Should -Not -Match 'linking plans/'
        $out | Should -Not -Match 'linking scripts/ticket/fixtures'
        $out | Should -Not -Match 'linking skills/b/README.md'
    }
}

Describe 'Assert-AgenticFlow worktype-templates' {
    It 'fails a workType with no template, and passes once it maps to an existing file' {
        $root = New-FlowRoot 'worktype'
        Write-Doc $root 'INDEX.md' ''
        Write-Doc $root 'skills/start-ticket/references/bug-fix.md' 'bug'
        Write-Doc $root 'skills/start-ticket/references/feature-plan.md' 'feature'
        $router = "- ``workType``: ``bug`` | ``feature`` | ``refactor``.`n`n  and the work-type template: bug → ``skills/start-ticket/references/bug-fix.md``; feature → ``skills/start-ticket/references/feature-plan.md``.`n"
        Write-Doc $root 'skills/ticket-router/SKILL.md' $router
        (Invoke-Gate $root) | Should -Match "worktype-templates: workType 'refactor' has no plan template"

        $router = $router -replace 'feature →', 'feature and refactor →'
        Write-Doc $root 'skills/ticket-router/SKILL.md' $router
        (Invoke-Gate $root) | Should -Not -Match 'worktype-templates'
    }
}
