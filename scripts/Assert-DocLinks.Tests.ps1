#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for Assert-DocLinks.ps1 check 4 (stale code paths).

.DESCRIPTION
    Each test builds a throwaway workspace: <ws>/workflow as -Root and a sibling
    <ws>/web, so sibling and in-repo paths can both be exercised.
    Run: Invoke-Pester ./scripts/Assert-DocLinks.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $script:Gate = Join-Path $PSScriptRoot 'Assert-DocLinks.ps1'

    function New-Workspace([string]$Name) {
        $ws = Join-Path $TestDrive $Name
        $root = Join-Path $ws 'workflow'
        foreach ($d in @('skills/a', 'rules', 'scripts/ticket', '_shared')) {
            New-Item -ItemType Directory -Path (Join-Path $root $d) -Force | Out-Null
        }
        New-Item -ItemType Directory -Path (Join-Path $ws 'web/src') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $ws 'web/src/app.ts') -Value 'x'
        Set-Content -LiteralPath (Join-Path $root 'rules/x.mdc') -Value 'x'
        Set-Content -LiteralPath (Join-Path $root 'profile.json') -Value '{ "repos": [ { "name": "web", "path": "../web" } ] }'
        return $root
    }
    function Write-Skill([string]$Root, [string]$Text) {
        Set-Content -LiteralPath (Join-Path $Root 'skills/a/SKILL.md') -Value $Text -Encoding UTF8
    }
    function Invoke-Gate([string]$Root) {
        $out = & pwsh -NoProfile -File $script:Gate -Root $Root 2>&1 | Out-String
        return [pscustomobject]@{ Out = $out; Code = $LASTEXITCODE }
    }
}

Describe 'Assert-DocLinks stale code paths' {
    It 'fails a backticked in-repo path that does not exist' {
        $root = New-Workspace 'missing'
        Write-Skill $root 'Read `rules/missing.mdc` first.'
        $r = Invoke-Gate $root
        $r.Code | Should -Be 1
        $r.Out | Should -Match 'stale code path'
        $r.Out | Should -Match 'rules/missing\.mdc'
    }

    It 'fails a glob that matches nothing, and passes paths and globs that resolve' {
        $root = New-Workspace 'globs'
        Write-Skill $root 'See `workflow/rules/react-*.mdc`.'
        (Invoke-Gate $root).Out | Should -Match 'react-\*\.mdc'

        Write-Skill $root 'See `rules/x.mdc`, `rules/*.mdc`, and `workflow/rules/x.mdc`.'
        $r = Invoke-Gate $root
        $r.Code | Should -Be 0
        $r.Out | Should -Match '3 code path\(s\) resolve'
    }

    It 'always fails a path into <Sibling>/workflow/, as a span or a link' {
        $root = New-Workspace 'sibling-flow'
        Write-Skill $root ('`web/workflow/skills/x/SKILL.md` and ' +
            '[skill](../../../web/workflow/skills/x/SKILL.md)')
        $r = Invoke-Gate $root
        $r.Code | Should -Be 1
        ([regex]::Matches($r.Out, 'workflow is a sibling of web')).Count | Should -Be 2
    }

    It 'only warns on a sibling-repo path that is missing, and passes one that exists' {
        $root = New-Workspace 'sibling-warn'
        Write-Skill $root 'Edit `web/src/app.ts`, not `web/src/gone.ts`.'
        $r = Invoke-Gate $root
        $r.Code | Should -Be 0
        $r.Out | Should -Match '\[WARN\] 1 sibling-repo path'
        $r.Out | Should -Match 'web/src/gone\.ts'
        $r.Out | Should -Not -Match 'app\.ts'
    }

    It 'ignores fenced code, placeholders, other repos'' folders, and case mismatches' {
        $root = New-Workspace 'ignored'
        $text = @(
            '`plans/TICKET-<n>-manifest.json`, `skills/<name>/SKILL.md`, `Scripts/react/src/x.ts`,'
            '`hooks/useThing.ts`, `scripts/Setup-LocalEnvironment.ps1`, `references/plan.md`'
            '```text'
            'rules/not-checked.mdc'
            '`rules/not-checked-either.mdc`'
            '```'
        ) -join "`n"
        Write-Skill $root $text
        $r = Invoke-Gate $root
        $r.Code | Should -Be 0
        $r.Out | Should -Not -Match 'stale code path'
    }

    It 'passes a missing path that git ignores (a runtime file)' {
        $root = New-Workspace 'ignored-runtime'
        & git -C $root init -q
        Set-Content -LiteralPath (Join-Path $root '.gitignore') -Value 'scripts/ticket/.state.json'
        Write-Skill $root 'State lives in `scripts/ticket/.state.json`; see `scripts/ticket/Gone.ps1`.'
        $r = Invoke-Gate $root
        $r.Code | Should -Be 1
        $r.Out | Should -Match 'Gone\.ps1'
        $r.Out | Should -Not -Match '\.state\.json'
    }
}
