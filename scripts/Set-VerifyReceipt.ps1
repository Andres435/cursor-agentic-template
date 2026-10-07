#Requires -Version 7
# Forwarder — body lives in ticket/Set-VerifyReceipt.ps1.
& (Join-Path $PSScriptRoot "ticket/Set-VerifyReceipt.ps1") @args
exit $LASTEXITCODE
