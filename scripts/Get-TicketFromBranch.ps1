#Requires -Version 7
# Forwarder — body lives in ticket/Get-TicketFromBranch.ps1.
& (Join-Path $PSScriptRoot "ticket/Get-TicketFromBranch.ps1") @args
exit $LASTEXITCODE
