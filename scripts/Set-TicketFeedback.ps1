# Forwarder — body lives in ticket/Set-TicketFeedback.ps1.
# Pipe only when something was piped in: an empty $input would swallow a -Json parameter.
$target = Join-Path $PSScriptRoot "ticket/Set-TicketFeedback.ps1"
if ($MyInvocation.ExpectingInput) { $input | & $target @args } else { & $target @args }
exit $LASTEXITCODE
