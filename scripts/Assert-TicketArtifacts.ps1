# Forwarder — body moved to ticket/Assert-TicketArtifacts.ps1. Keep this shim for one release.
& (Join-Path $PSScriptRoot "ticket/Assert-TicketArtifacts.ps1") @args
exit $LASTEXITCODE
