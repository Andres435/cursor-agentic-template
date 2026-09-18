# Forwarder — body lives in ticket/Get-ReviewSkip.ps1.
& (Join-Path $PSScriptRoot "ticket/Get-ReviewSkip.ps1") @args
exit $LASTEXITCODE
