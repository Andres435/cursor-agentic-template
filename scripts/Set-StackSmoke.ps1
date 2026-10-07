#Requires -Version 7
# Forwarder — body lives in ticket/Set-StackSmoke.ps1.
& (Join-Path $PSScriptRoot "ticket/Set-StackSmoke.ps1") @args
exit $LASTEXITCODE
