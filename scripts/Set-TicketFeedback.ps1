# Forwarder — body lives in ticket/Set-TicketFeedback.ps1.
$input | & (Join-Path $PSScriptRoot "ticket/Set-TicketFeedback.ps1") @args
exit $LASTEXITCODE
