#Requires -Version 7
# Forwarder — body lives in ticket/Set-TicketLanes.ps1.
& (Join-Path $PSScriptRoot "ticket/Set-TicketLanes.ps1") @args
exit $LASTEXITCODE
