# Forwarder — body lives in ticket/Set-TicketCtxPct.ps1.
& (Join-Path $PSScriptRoot "ticket/Set-TicketCtxPct.ps1") @args
exit $LASTEXITCODE
