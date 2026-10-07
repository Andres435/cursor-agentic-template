#Requires -Version 7
# Forwarder — body lives in ticket/Get-StackSmoke.ps1.
& (Join-Path $PSScriptRoot "ticket/Get-StackSmoke.ps1") @args
exit $LASTEXITCODE
