#Requires -Version 7
# Forwarder — body moved to ticket/Resolve-TicketRoot.ps1. Keep this shim for one release.
& (Join-Path $PSScriptRoot "ticket/Resolve-TicketRoot.ps1") @args
exit $LASTEXITCODE
