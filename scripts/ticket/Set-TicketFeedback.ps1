#Requires -Version 7
<#
.SYNOPSIS
    Record compact PR + static-analysis feedback on the ticket manifest (manifest.feedback).

.DESCRIPTION
    /address-pr-comments calls this once with the merged pr-feedback-fetch packets, and
    again after triage or fixes to save the updated list. The manifest is the one record:
    there is no separate feedback file. The whole feedback object is replaced each call;
    read manifest.feedback, change it, and write it back.

    Shape (JSON):
      {
        "prs":   [ { "repo", "id", "url", "source", "target", "status", "tip" } ],
        "gate":  [ { "repo", "pr", "status", "coverageNew", "duplicationNew" } ],
        "items": [ { "kind": "thread|sonar|metric", "repo", "pr", "ref", "status", "file",
                     "author", "ask", "context", "triage", "note" } ]
      }
    triage is one of: fix-now, clarify, out-of-scope, addressed, metric, closed.
    fetchedAtUtc is stamped here unless the JSON already carries it.

.PARAMETER Ticket
    Work item, with or without the ticket prefix.

.PARAMETER Json
    The feedback object as JSON. Also accepted from the pipeline.

.PARAMETER Root
    Override the workflow repo root (tests).

.EXAMPLE
    $packet | .\Set-TicketFeedback.ps1 -Ticket TICKET-42
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ticket,
    [Parameter(ValueFromPipeline)][string]$Json,
    [string]$Root
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    . (Join-Path (Join-Path $PSScriptRoot 'lib') 'ManifestFields.ps1')
    $chunks = New-Object System.Collections.Generic.List[string]
}

process {
    if ($null -ne $Json) { [void]$chunks.Add($Json) }
}

end {
    $text = ($chunks -join "`n").Trim()
    if (-not $text) { throw "Pass the feedback JSON with -Json or on the pipeline." }

    $Key = Get-TicketKeyFromRaw -Ticket $Ticket
    $RepoRoot = if ($Root) { $Root } else { Get-CursorRepoRoot -FromScriptRoot $PSScriptRoot }
    $manifestPath = Get-TicketManifestFile -RepoRoot $RepoRoot -TicketKey $Key
    if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Manifest not found: $manifestPath" }

    $feedback = $text | ConvertFrom-Json
    $names = @($feedback.PSObject.Properties.Name)
    foreach ($required in @('prs', 'items')) {
        if ($names -notcontains $required) { throw "Feedback JSON needs a '$required' array." }
    }
    $triage = @('fix-now', 'clarify', 'out-of-scope', 'addressed', 'metric', 'closed')
    $kinds = @('thread', 'sonar', 'metric')
    foreach ($item in @($feedback.items)) {
        if (-not $item) { continue }
        $ref = Get-StampEntryValue $item 'ref'
        if ((Get-StampEntryValue $item 'kind') -notin $kinds) { throw "Item '$ref': kind must be one of $($kinds -join ', ')." }
        if ((Get-StampEntryValue $item 'triage') -notin $triage) { throw "Item '$ref': triage must be one of $($triage -join ', ')." }
        if (-not (Get-StampEntryValue $item 'ask')) { throw "Item '$ref': ask is required (one sentence)." }
    }
    if ($names -notcontains 'fetchedAtUtc') {
        $feedback | Add-Member -NotePropertyName fetchedAtUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o'))
    }

    Merge-TicketManifestFields -ManifestPath $manifestPath -Patch @{ feedback = $feedback }
    $open = @($feedback.items | Where-Object { $_ -and $_.triage -in @('fix-now', 'clarify', 'metric') }).Count
    Write-Host "Wrote feedback ($(@($feedback.items).Count) items, $open open) on $manifestPath" -ForegroundColor Green
}
