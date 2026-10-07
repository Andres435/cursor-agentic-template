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

Describe 'Assert-AgenticFlow ide-neutral bans' {
    It 'fails a model name in any case and a Codex tool name, but not ordinary words' {
        $root = New-FlowRoot 'neutral'
        Write-Doc $root 'INDEX.md' ''
        Write-Doc $root 'skills/a/SKILL.md' "Dispatch to an opus lane.`nCall spawn_agent with the tier.`nThe SQL composer builds the query."
        $out = Invoke-Gate $root
        $out | Should -Match "skills/a/SKILL.md:1 names a model \('opus'\)"
        $out | Should -Match "skills/a/SKILL.md:2 names an IDE tool \('spawn_agent'\)"
        $out | Should -Not -Match "SKILL.md:3"
    }
}

Describe 'Assert-AgenticFlow read-only reviewer' {
    It 'fails a code-reviewer that can edit, and passes once the edit tools are disallowed' {
        $root = New-FlowRoot 'reviewer'
        Write-Doc $root 'INDEX.md' ''
        $front = "---`nname: code-reviewer`ndescription: Reviews changes.`n"
        Write-Doc $root 'agents/code-reviewer.md' ($front + "disallowedTools: Write`n---`n# Reviewer")
        $out = Invoke-Gate $root
        $out | Should -Match "code-reviewer.md must list 'Edit' in disallowedTools"
        $out | Should -Match "code-reviewer.md must list 'NotebookEdit' in disallowedTools"
        $out | Should -Not -Match "must list 'Write'"

        Write-Doc $root 'agents/code-reviewer.md' ($front + "disallowedTools: Edit, Write, NotebookEdit`n---`n# Reviewer")
        (Invoke-Gate $root) | Should -Not -Match 'disallowedTools'
    }
}

Describe 'Assert-AgenticFlow doc claims' {
    It 'fails a forbidden phrase with file:line, a missing required phrase, and a vanished anchor' {
        $root = New-FlowRoot 'claims'
        Write-Doc $root 'INDEX.md' ''
        Write-Doc $root 'scripts/ticket/doc-claims.psd1' @'
@{
    Claims = @(
        @{
            Id      = 'gate-required'
            Why     = 'Close needs the Drive.'
            Anchor  = @{ File = 'src/gate.txt'; Pattern = 'function Test-UiEvidence' }
            Require = @( @{ File = 'MANUAL.md'; Pattern = 'Drive is required' } )
            Forbid  = @( @{ Pattern = 'does not block close'; Except = @('notes/*') } )
        }
    )
    CoChange = @()
}
'@
        Write-Doc $root 'src/gate.txt' 'function Test-UiEvidence { }'
        Write-Doc $root 'MANUAL.md' "Intro.`nSkipping it does not block close."
        Write-Doc $root 'notes/history.md' 'It once did not: does not block close.'
        $out = Invoke-Gate $root
        $out | Should -Match "doc-claims: gate-required -- MANUAL.md:2 contradicts the claim"
        $out | Should -Match "doc-claims: gate-required -- MANUAL.md must match /Drive is required/"
        $out | Should -Not -Match 'doc-claims: .*notes/history\.md'
        $out | Should -Not -Match 'anchor gone'

        Write-Doc $root 'src/gate.txt' 'function Test-Renamed { }'
        Write-Doc $root 'MANUAL.md' 'The Drive is required to close.'
        $out = Invoke-Gate $root
        $out | Should -Match 'doc-claims: gate-required -- anchor gone: src/gate.txt'
        $out | Should -Not -Match 'contradicts the claim'
        $out | Should -Not -Match 'must match'
    }
}
