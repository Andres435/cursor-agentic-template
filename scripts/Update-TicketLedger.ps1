#Requires -Version 7
# Forwarder — body moved to ticket/Update-TicketLedger.ps1. Keep this shim for one release.
& (Join-Path $PSScriptRoot "ticket/Update-TicketLedger.ps1") @args
exit $LASTEXITCODE
