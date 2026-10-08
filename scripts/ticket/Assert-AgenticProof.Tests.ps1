#Requires -Modules Pester
<#
.SYNOPSIS
    Pester 5 tests for Assert-AgenticProof.ps1: the standalone check of the Agentic-Proof trailer,
    including fingerprint parity with the trailer Get-AgenticProof.ps1 writes.
#>

BeforeAll {
    $script:Assert = Join-Path $PSScriptRoot 'Assert-AgenticProof.ps1'
    $script:Proof = Join-Path $PSScriptRoot 'Get-AgenticProof.ps1'
    $script:Verify = Join-Path $PSScriptRoot 'Set-VerifyReceipt.ps1'
    $script:Review = Join-Path $PSScriptRoot 'Set-ReviewReady.ps1'
    . (Join-Path (Join-Path $PSScriptRoot 'lib') 'ManifestFields.ps1')

    function Invoke-Git([string]$Repo, [string[]]$GitArgs) {
        & git -C $Repo -c user.email=t@e.com -c user.name=t @GitArgs 2>&1 | Out-Null
    }
    function New-Repo([string]$Name) {
        $repo = Join-Path $TestDrive "$Name-repo"
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        Invoke-Git $repo @('init', '-q')
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'one'
        Invoke-Git $repo @('add', 'a.txt')
        Invoke-Git $repo @('commit', '-q', '-m', 'init')
        return $repo
    }
    # Stage a change, stamp it for real, and return the trailer line Get-AgenticProof prints.
    function New-TrailerLine([string]$Name, [string]$Repo) {
        $root = Join-Path $TestDrive "$Name-root"
        New-Item -ItemType Directory -Path (Join-Path $root 'plans') -Force | Out-Null
        '{"mode":"branch"}' | Set-Content -LiteralPath (Join-Path $root 'plans/WI00030-manifest.json') -Encoding UTF8
        $ev = Join-Path $TestDrive "$Name-ev.log"
        [System.IO.File]::WriteAllText($ev, "Passed! total 3 $Name")
        Set-Content -LiteralPath (Join-Path $Repo 'a.txt') -Value "work $Name"
        Invoke-Git $Repo @('add', 'a.txt')
        & $script:Verify -Ticket WI00030 -Repo app -Tests pass -Sonar ok -Evidence $ev -RepoPath $Repo -Root $root *>&1 | Out-Null
        & $script:Review -Ticket WI00030 -Mode staged -Verdicts (ConvertTo-Json -Compress -InputObject @{ app = 'Ready' }) -RepoPaths (ConvertTo-Json -Compress -InputObject @{ app = $Repo }) -Root $root *>&1 | Out-Null
        return (& $script:Proof -Ticket WI00030 -Repo app -RepoPath $Repo -Root $root)
    }
    # A repo whose tip is the staged work committed with a genuine trailer.
    function New-ProvenRepo([string]$Name) {
        $repo = New-Repo $Name
        $line = New-TrailerLine $Name $repo
        Invoke-Git $repo @('commit', '-q', '-m', 'work', '-m', $line)
        return [pscustomobject]@{ repo = $repo; line = $line }
    }
    function Invoke-Check([string]$Repo, [hashtable]$More = @{}) {
        $out = & $script:Assert -RepoPath $Repo @More
        return [pscustomobject]@{ out = ($out -join "`n"); code = $LASTEXITCODE }
    }
    function Get-Head([string]$Repo) { return ((& git -C $Repo rev-parse HEAD) | Out-String).Trim() }
}

Describe 'Assert-AgenticProof' {
    It 'PASSes a commit made from the staged work, and the trailer fp equals the commit diff fp (parity)' {
        $p = New-ProvenRepo 'pass'
        $r = Invoke-Check $p.repo
        $r.code | Should -Be 0
        $r.out | Should -Match '^\[PASS\] agentic-proof: [0-9a-f]{7} '
        $fp = ($p.line -replace '^.* fp=([0-9a-f]{64}) .*$', '$1')
        $fp | Should -Be (Get-RangeDiffFingerprint -RepoPath $p.repo -From 'HEAD~1' -To 'HEAD')
    }

    It 'FAILs when the commit is amended with a different file' {
        $p = New-ProvenRepo 'tamper'
        Set-Content -LiteralPath (Join-Path $p.repo 'b.txt') -Value 'sneaky'
        Invoke-Git $p.repo @('add', 'b.txt')
        Invoke-Git $p.repo @('commit', '-q', '--amend', '--no-edit')
        $r = Invoke-Check $p.repo
        $r.code | Should -Be 1
        $r.out | Should -Match '^\[FAIL\] agentic-proof: .*mismatch'
    }

    It 'reports INFO and exits 0 when the trailer is missing, and exits 1 with -Require' {
        $repo = New-Repo 'missing'
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'plain'
        Invoke-Git $repo @('commit', '-q', '-a', '-m', 'no proof')
        $r = Invoke-Check $repo
        $r.code | Should -Be 0
        $r.out | Should -Match '^\[INFO\] agentic-proof: no Agentic-Proof trailer on [0-9a-f]{7}$'
        $q = Invoke-Check $repo @{ Require = $true }
        $q.code | Should -Be 1
        $q.out | Should -Match '^\[FAIL\] agentic-proof: .*required'
    }

    It 'verifies the work commit beneath a merge of the base branch' {
        $repo = New-Repo 'merge'
        $main = ((& git -C $repo branch --show-current) | Out-String).Trim()
        Invoke-Git $repo @('checkout', '-q', '-b', 'side')
        Set-Content -LiteralPath (Join-Path $repo 'c.txt') -Value 'base work'
        Invoke-Git $repo @('add', 'c.txt')
        Invoke-Git $repo @('commit', '-q', '-m', 'base change')
        Invoke-Git $repo @('checkout', '-q', $main)
        $line = New-TrailerLine 'merge' $repo
        Invoke-Git $repo @('commit', '-q', '-m', 'work', '-m', $line)
        $workSha = Get-Head $repo
        Invoke-Git $repo @('merge', '-q', '--no-ff', '-m', 'merge base', 'side')
        (Get-Head $repo) | Should -Not -Be $workSha
        $r = Invoke-Check $repo
        $r.code | Should -Be 0
        $r.out | Should -Match "^\[PASS\] agentic-proof: $($workSha.Substring(0, 7)) "
    }

    It 'FAILs a malformed trailer' -ForEach @(
        @{ name = 'garbage'; value = 'Agentic-Proof: v1 garbage' }
        @{ name = 'badhex'; value = 'Agentic-Proof: v1 fp=ABC verify=pass evidence=none review=ready' }
        @{ name = 'badver'; value = ('Agentic-Proof: v2 fp=' + ('a' * 64) + ' verify=pass evidence=none review=ready') }
        @{ name = 'badverify'; value = ('Agentic-Proof: v1 fp=' + ('a' * 64) + ' verify=fail evidence=none review=ready') }
        @{ name = 'badreview'; value = ('Agentic-Proof: v1 fp=' + ('a' * 64) + ' verify=pass evidence=none review=blocked') }
        @{ name = 'badevid'; value = ('Agentic-Proof: v1 fp=' + ('a' * 64) + ' verify=pass evidence=xyz review=ready') }
    ) {
        $repo = New-Repo "bad-$name"
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'x'
        Invoke-Git $repo @('commit', '-q', '-a', '-m', 'work', '-m', $value)
        $r = Invoke-Check $repo
        $r.code | Should -Be 1
        $r.out | Should -Match '^\[FAIL\] agentic-proof: '
    }

    It 'FAILs a well-formed trailer whose fp does not match the diff' {
        $repo = New-Repo 'wrongfp'
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'x'
        Invoke-Git $repo @('commit', '-q', '-a', '-m', 'work', '-m', ('Agentic-Proof: v1 fp=' + ('a' * 64) + ' verify=pass evidence=none review=ready'))
        $r = Invoke-Check $repo
        $r.code | Should -Be 1
        $r.out | Should -Match 'mismatch'
    }

    It 'uses -Base to pick the newest work commit in the range' {
        $p = New-ProvenRepo 'range'
        $proven = Get-Head $p.repo
        Set-Content -LiteralPath (Join-Path $p.repo 'a.txt') -Value 'later'
        Invoke-Git $p.repo @('commit', '-q', '-a', '-m', 'later, no proof')
        $tip = Invoke-Check $p.repo @{ Base = 'HEAD~2' }
        $tip.code | Should -Be 0
        $tip.out | Should -Match '^\[INFO\] '
        $older = Invoke-Check $p.repo @{ Base = 'HEAD~2'; Commit = $proven }
        $older.code | Should -Be 0
        $older.out | Should -Match "^\[PASS\] agentic-proof: $($proven.Substring(0, 7)) "
        $none = Invoke-Check $p.repo @{ Base = 'HEAD' }
        $none.code | Should -Be 1
        $none.out | Should -Match '^\[FAIL\] .*no non-merge commit'
    }

    It 'verifies a root commit against the empty tree' {
        $repo = Join-Path $TestDrive 'root-repo'
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        Invoke-Git $repo @('init', '-q')
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'first'
        Invoke-Git $repo @('add', 'a.txt')
        $fp = Get-StagedDiffFingerprint -RepoPath $repo
        Invoke-Git $repo @('commit', '-q', '-m', 'root', '-m', "Agentic-Proof: v1 fp=$fp verify=pass evidence=none review=ready")
        $r = Invoke-Check $repo
        $r.code | Should -Be 0
        $r.out | Should -Match '^\[PASS\] '
    }

    It 'FAILs cleanly on a shallow clone that lacks the parent' {
        $p = New-ProvenRepo 'shallowsrc'
        $clone = Join-Path $TestDrive 'shallow-clone'
        & git clone -q --depth 1 ('file:///' + ($p.repo -replace '\\', '/')) $clone 2>&1 | Out-Null
        $r = Invoke-Check $clone
        $r.code | Should -Be 1
        $r.out | Should -Match '^\[FAIL\] agentic-proof: .*not available'
    }

    It 'prints one JSON object with ok, sha, reason, present' {
        $p = New-ProvenRepo 'json'
        $r = Invoke-Check $p.repo @{ Json = $true }
        $r.code | Should -Be 0
        $o = $r.out | ConvertFrom-Json
        @($o.PSObject.Properties.Name) | Should -Be @('ok', 'sha', 'reason', 'present')
        $o.ok | Should -BeTrue
        $o.present | Should -BeTrue
        $o.sha | Should -Be (Get-Head $p.repo)
        $repo = New-Repo 'json-missing'
        $m = Invoke-Check $repo @{ Json = $true; Require = $true }
        $m.code | Should -Be 1
        $mo = $m.out | ConvertFrom-Json
        $mo.ok | Should -BeFalse
        $mo.present | Should -BeFalse
    }
}
