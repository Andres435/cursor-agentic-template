#Requires -Version 7
# Forwarder — body lives in ticket/Select-TicketStagePaths.ps1.
& (Join-Path $PSScriptRoot "ticket/Select-TicketStagePaths.ps1") @args
exit $LASTEXITCODE
