#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for Get-AgenticProof.ps1: the Agentic-Proof trailer line is printed only when
    both genuine stamps still describe the staged work.
#>

BeforeAll {
    $script:Proof = Join-Path $PSScriptRoot 'Get-AgenticProof.ps1'
    $script:Verify = Join-Path $PSScriptRoot 'Set-VerifyReceipt.ps1'
    $script:Review = Join-Path $PSScriptRoot 'Set-ReviewReady.ps1'
    . (Join-Path (Join-Path $PSScriptRoot 'lib') 'ManifestFields.ps1')

    function Invoke-Git([string]$Repo, [string[]]$GitArgs) {
        & git -C $Repo -c user.email=t@e.com -c user.name=t @GitArgs 2>&1 | Out-Null
    }
    # A Root with the manifest and a repo holding one commit plus one staged change.
    function New-ProofCase([string]$Name, [switch]$NoStage) {
        $root = Join-Path $TestDrive "$Name-root"
        New-Item -ItemType Directory -Path (Join-Path $root 'plans') -Force | Out-Null
        '{"mode":"branch"}' | Set-Content -LiteralPath (Join-Path $root 'plans/WI00030-manifest.json') -Encoding UTF8
        $repo = Join-Path $TestDrive "$Name-repo"
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        Invoke-Git $repo @('init', '-q')
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'one'
        Invoke-Git $repo @('add', 'a.txt')
        Invoke-Git $repo @('commit', '-q', '-m', 'init')
        if (-not $NoStage) {
            Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'two'
            Invoke-Git $repo @('add', 'a.txt')
        }
        $ev = Join-Path $TestDrive "$Name-ev.log"
        [System.IO.File]::WriteAllText($ev, "Passed! total 3 $Name")
        return [pscustomobject]@{ root = $root; repo = $repo; evidence = $ev }
    }
    function Set-Stamps($Case, [string]$Verdict = 'Ready') {
        & $script:Verify -Ticket WI00030 -Repo app -Tests pass -Sonar ok -Evidence $Case.evidence -RepoPath $Case.repo -Root $Case.root *>&1 | Out-Null
        $paths = ConvertTo-Json -Compress -InputObject @{ app = $Case.repo }
        & $script:Review -Ticket WI00030 -Mode staged -Verdicts (ConvertTo-Json -Compress -InputObject @{ app = $Verdict }) -RepoPaths $paths -Root $Case.root *>&1 | Out-Null
    }
    function Get-Manifest($Case) {
        return (Get-Content -LiteralPath (Join-Path $Case.root 'plans/WI00030-manifest.json') -Raw | ConvertFrom-Json)
    }
}

Describe 'Get-AgenticProof' {
    It 'prints the exact trailer line for genuine stamps on the staged work' {
        $c = New-ProofCase 'happy'
        Set-Stamps $c
        $m = Get-Manifest $c
        $fp = Get-StagedDiffFingerprint -RepoPath $c.repo
        $line = & $script:Proof -Ticket WI00030 -Repo app -RepoPath $c.repo -Root $c.root
        $short = $m.verify.repos.app.evidence.sha256.Substring(0, 12)
        $line | Should -Be "Agentic-Proof: v1 fp=$fp verify=pass evidence=$short review=ready"
        $line | Should -Match '^Agentic-Proof: v1 fp=[0-9a-f]{64} verify=pass evidence=[0-9a-f]{12} review=ready$'
    }

    It 'maps Ready with fixes to ready-with-fixes' {
        $c = New-ProofCase 'fixes'
        Set-Stamps $c 'Ready with fixes'
        (& $script:Proof -Ticket WI00030 -Repo app -RepoPath $c.repo -Root $c.root) | Should -Match 'review=ready-with-fixes$'
    }

    It 'prints evidence=none for a not-run receipt with a reason' {
        $c = New-ProofCase 'notrun'
        & $script:Verify -Ticket WI00030 -Repo app -Tests not-run -Sonar not-run -Reason 'docs-only' -RepoPath $c.repo -Root $c.root *>&1 | Out-Null
        & $script:Review -Ticket WI00030 -Mode staged -Verdicts (ConvertTo-Json -Compress -InputObject @{ app = 'Ready' }) -RepoPaths (ConvertTo-Json -Compress -InputObject @{ app = $c.repo }) -Root $c.root *>&1 | Out-Null
        (& $script:Proof -Ticket WI00030 -Repo app -RepoPath $c.repo -Root $c.root) | Should -Match 'evidence=none review=ready$'
    }

    It 'refuses a stale stamp after the staged work changes' {
        $c = New-ProofCase 'stale'
        Set-Stamps $c
        Set-Content -LiteralPath (Join-Path $c.repo 'a.txt') -Value 'three'
        Invoke-Git $c.repo @('add', 'a.txt')
        { & $script:Proof -Ticket WI00030 -Repo app -RepoPath $c.repo -Root $c.root } | Should -Throw '*stale*'
    }

    It 'refuses a Not ready verdict' {
        $c = New-ProofCase 'notready'
        Set-Stamps $c 'Not ready'
        { & $script:Proof -Ticket WI00030 -Repo app -RepoPath $c.repo -Root $c.root } | Should -Throw '*Not ready*'
    }

    It 'refuses a missing verify receipt' {
        $c = New-ProofCase 'noverify'
        & $script:Review -Ticket WI00030 -Mode staged -Verdicts (ConvertTo-Json -Compress -InputObject @{ app = 'Ready' }) -RepoPaths (ConvertTo-Json -Compress -InputObject @{ app = $c.repo }) -Root $c.root *>&1 | Out-Null
        { & $script:Proof -Ticket WI00030 -Repo app -RepoPath $c.repo -Root $c.root } | Should -Throw '*verify*'
    }

    It 'refuses a failed verify receipt' {
        $c = New-ProofCase 'failverify'
        & $script:Verify -Ticket WI00030 -Repo app -Tests fail -Sonar ok -Evidence $c.evidence -RepoPath $c.repo -Root $c.root *>&1 | Out-Null
        & $script:Review -Ticket WI00030 -Mode staged -Verdicts (ConvertTo-Json -Compress -InputObject @{ app = 'Ready' }) -RepoPaths (ConvertTo-Json -Compress -InputObject @{ app = $c.repo }) -Root $c.root *>&1 | Out-Null
        { & $script:Proof -Ticket WI00030 -Repo app -RepoPath $c.repo -Root $c.root } | Should -Throw '*pass*'
    }

    It 'refuses a missing review stamp' {
        $c = New-ProofCase 'noreview'
        & $script:Verify -Ticket WI00030 -Repo app -Tests pass -Sonar ok -Evidence $c.evidence -RepoPath $c.repo -Root $c.root *>&1 | Out-Null
        { & $script:Proof -Ticket WI00030 -Repo app -RepoPath $c.repo -Root $c.root } | Should -Throw '*reviewReady*'
    }

    It 'refuses an empty staged diff' {
        $c = New-ProofCase 'empty'
        Set-Stamps $c
        Invoke-Git $c.repo @('reset', '-q')
        { & $script:Proof -Ticket WI00030 -Repo app -RepoPath $c.repo -Root $c.root } | Should -Throw '*Nothing staged*'
    }

    It 'refuses when the manifest is missing' {
        $c = New-ProofCase 'nomanifest'
        { & $script:Proof -Ticket WI00031 -Repo app -RepoPath $c.repo -Root $c.root } | Should -Throw '*Manifest not found*'
    }
}
