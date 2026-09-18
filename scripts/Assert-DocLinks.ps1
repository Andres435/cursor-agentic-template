<#
.SYNOPSIS
    Link gate for workflow documentation. Fails on relative links that do not
    resolve, and on link labels that name a path that does not exist.

.DESCRIPTION
    Three checks, in descending order of how much damage they prevent:

    Links that resolve OUTSIDE this repo are out of scope for every check --
    ../../TmoPro/..., ../../TmoDocs/..., a sibling's .cursor. Whether they
    resolve depends on the developer's workspace layout, and CI checks out this
    repo alone, so validating them would fail there and nowhere else.

      1. BROKEN TARGET  (hard fail)
         A relative link whose target file does not exist. The corpus exists to
         tell a model where to look; a doc that names a file it cannot open
         sends the reader away with nothing. The 2026 capability reorg inserted
         a directory level under skills/ and left 100+ links one '../' short —
         this check is what stops that class from coming back.

      2. STALE LABEL    (hard fail)
         Many docs use the path itself as the visible link text:
             [../../_shared/foo.md](../../../_shared/foo.md)
         When only the target is repaired the label still names a path that
         does not exist, and a reader following the rendered text — human or
         model — goes to the wrong place. Only labels that are themselves
         relative paths ('../' or './') are checked; readable labels such as
         '.cursor/rules/x.mdc' or a prose label are deliberate and ignored.

      3. TIER CYCLE    (hard fail)
         A _shared/ contract and a skills/ doc that link at each other. A
         ONE-WAY contract -> skill link is just a reference and is allowed;
         only the mutual pair is a cycle, because the phase doc already points
         up at the contract. Redirect stubs (a 'Canonical:' line) and README
         indexes are exempt — both are navigational by design.

    This is a CORRECTNESS gate, not a growth gate. Assert-DocBudget.ps1 owns
    size. Exit 0 = pass, 1 = at least one hard failure.

.PARAMETER Root
    Workspace root (the .cursor repo dir). Defaults to the parent of $PSScriptRoot.

.PARAMETER WarnOnly
    Print violations but exit 0 (advisory mode, suitable for CI comments).

.EXAMPLE
    .\scripts\Assert-DocLinks.ps1

.EXAMPLE
    .\scripts\Assert-DocLinks.ps1 -WarnOnly
    # Advisory; always exits 0.

.NOTES
    UTF-8 encoding note: read with -Encoding UTF8 so BOM-less UTF-8 does not
    decode as ANSI on Windows PowerShell 5.1.
#>

[CmdletBinding()]
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent),
    [switch]$WarnOnly
)

Set-StrictMode -Version Latest

# Ticket artifacts and test fixtures are out of scope: WI*-plan files reference
# source paths in sibling repos, and fixtures must stay byte-stable for tests.
$excluded = @('tmp/*', 'scripts/ticket/fixtures/*', 'plans/WI*', 'node_modules/*')

$linkPattern = '\[([^\]]*)\]\(([^)\s]+)\)'

$brokenTargets  = [System.Collections.Generic.List[object]]::new()
$staleLabels    = [System.Collections.Generic.List[object]]::new()
$tierCandidates = [System.Collections.Generic.List[object]]::new()
$tierWarnings   = [System.Collections.Generic.List[object]]::new()
$checked        = 0
$external       = 0

# Links that resolve outside this repo (../../TmoPro/..., ../../TmoDocs/..., a
# sibling's .cursor) point at repos cloned beside this one. Whether they resolve
# depends on the developer's workspace layout, and on CI nothing but this repo is
# checked out -- so they are out of scope rather than broken.
$RootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')

function Test-InsideRepo {
    param([string]$FullPath)
    return $FullPath.StartsWith($RootFull + [IO.Path]::DirectorySeparatorChar) -or $FullPath -eq $RootFull
}

$docs = @(Get-ChildItem -LiteralPath $RootFull -Recurse -File -Include '*.md', '*.mdc' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' })

foreach ($doc in $docs) {
    $relative = ($doc.FullName.Substring($RootFull.Length).TrimStart('\', '/') -replace '\\', '/')

    $skip = $false
    foreach ($ex in $excluded) { if ($relative -like $ex) { $skip = $true; break } }
    if ($skip) { continue }

    $text = Get-Content -LiteralPath $doc.FullName -Encoding UTF8 -Raw -ErrorAction SilentlyContinue
    if (-not $text) { continue }
    $checked++

    $dir     = $doc.DirectoryName
    $isStub  = $text -match '(?m)^Canonical:'
    $isIndex = [IO.Path]::GetFileName($relative) -in @('README.md', 'INDEX.md')

    foreach ($m in [regex]::Matches($text, $linkPattern)) {
        $label  = $m.Groups[1].Value
        $target = $m.Groups[2].Value

        if ($target -match '^(https?://|mailto:|#)') { continue }

        # --- 1. broken target -------------------------------------------------
        $targetPath = ($target -split '#')[0]
        if ($targetPath) {
            $resolved = [IO.Path]::GetFullPath([IO.Path]::Combine($dir, ($targetPath -replace '/', [IO.Path]::DirectorySeparatorChar)))
            if (-not (Test-InsideRepo $resolved)) {
                $external++
                continue
            }
            if (-not (Test-Path -LiteralPath $resolved)) {
                $brokenTargets.Add([pscustomobject]@{ File = $relative; Link = $target })
            }
        }

        # --- 2. stale path label ---------------------------------------------
        if ($label -like '../*' -or $label -like './*') {
            $labelPath = (($label -split '#')[0] -split ' ')[0].Trim()
            if ($labelPath) {
                $lresolved = [IO.Path]::GetFullPath([IO.Path]::Combine($dir, ($labelPath -replace '/', [IO.Path]::DirectorySeparatorChar)))
                if ((Test-InsideRepo $lresolved) -and -not (Test-Path -LiteralPath $lresolved)) {
                    $staleLabels.Add([pscustomobject]@{ File = $relative; Label = $label; Target = $target })
                }
            }
        }

        # --- 3. tier direction (deferred; needs the full graph) ---------------
        # A one-way _shared/ -> skills/ link is just a reference and creates no
        # cycle. Only a MUTUAL pair does, so collect candidates here and decide
        # after every doc has been read.
        # Only this workspace's own skills/ tree — a link into a tracked repo's
        # .cursor (e.g. TmoPro/.cursor/skills/...) is a cross-repo reference.
        if ($relative -like '_shared/*' -and -not $isStub -and -not $isIndex -and $targetPath) {
            $tierResolved = [IO.Path]::GetFullPath([IO.Path]::Combine($dir, ($targetPath -replace '/', [IO.Path]::DirectorySeparatorChar)))
            $skillsRoot = [IO.Path]::GetFullPath([IO.Path]::Combine($Root, 'skills'))
            if ($tierResolved.StartsWith($skillsRoot + [IO.Path]::DirectorySeparatorChar)) {
                $tierCandidates.Add([pscustomobject]@{
                    File   = $relative
                    Link   = $target
                    Target = ($tierResolved.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/')
                })
            }
        }
    }
}

# --- resolve tier candidates into real cycles -------------------------------
# A candidate is a violation only when the skills/ doc links back to the same
# _shared/ contract: that mutual pair is the cycle. One-way references are fine.
foreach ($c in $tierCandidates) {
    $skillFile = Join-Path $Root ($c.Target -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $skillFile)) { continue }
    $skillText = Get-Content -LiteralPath $skillFile -Encoding UTF8 -Raw -ErrorAction SilentlyContinue
    if (-not $skillText) { continue }

    $contractName = [IO.Path]::GetFileName($c.File)
    $skillDir     = Split-Path -Parent $skillFile
    foreach ($bm in [regex]::Matches($skillText, $linkPattern)) {
        $backTarget = ($bm.Groups[2].Value -split '#')[0]
        if (-not $backTarget) { continue }
        if ([IO.Path]::GetFileName($backTarget) -ne $contractName) { continue }
        $backResolved = [IO.Path]::GetFullPath([IO.Path]::Combine($skillDir, ($backTarget -replace '/', [IO.Path]::DirectorySeparatorChar)))
        $contractFull = [IO.Path]::GetFullPath([IO.Path]::Combine($Root, ($c.File -replace '/', [IO.Path]::DirectorySeparatorChar)))
        if ($backResolved -eq $contractFull) {
            $tierWarnings.Add([pscustomobject]@{ File = $c.File; Link = $c.Link; Back = $c.Target })
            break
        }
    }
}

$hardFailures = $brokenTargets.Count + $staleLabels.Count + $tierWarnings.Count

if ($brokenTargets.Count) {
    Write-Host "[FAIL] $($brokenTargets.Count) broken link target(s):" -ForegroundColor Red
    foreach ($v in $brokenTargets) { Write-Host ("  {0,-58} -> {1}" -f $v.File, $v.Link) }
}

if ($staleLabels.Count) {
    Write-Host "[FAIL] $($staleLabels.Count) stale link label(s) — label names a path that does not exist:" -ForegroundColor Red
    foreach ($v in $staleLabels) { Write-Host ("  {0,-58} [{1}] -> ({2})" -f $v.File, $v.Label, $v.Target) }
}

if ($tierWarnings.Count) {
    $color = 'Red'
    $tag   = 'FAIL'
    Write-Host "[$tag] $($tierWarnings.Count) tier cycle(s) — a _shared/ contract and a skills/ doc link at each other:" -ForegroundColor $color
    foreach ($v in $tierWarnings) { Write-Host ("  {0,-46} <-> {1}" -f $v.File, $v.Back) }
    Write-Host "  Contracts are hubs: let the phase doc point up at the contract, not both ways."
}

if ($hardFailures -eq 0) {
    Write-Host "[PASS] Doc links: $checked file(s) checked, all targets and labels resolve, no tier cycles." -ForegroundColor Green
    if ($external) {
        Write-Host "       ($external link(s) into sibling repos not checked — they depend on workspace layout.)"
    }
    exit 0
}

if ($WarnOnly) { exit 0 }
exit 1
