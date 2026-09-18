# Forwarder — body lives in ticket/Set-ReviewReady.ps1.
& (Join-Path $PSScriptRoot "ticket/Set-ReviewReady.ps1") @args
exit $LASTEXITCODE
