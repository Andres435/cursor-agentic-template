# PSScriptAnalyzer settings for scripts/. CI fails on Error and Warning.
# Each exclusion names why the rule does not fit these CLI scripts.
@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'                     # launchers and gates print to the console on purpose
        'PSUseBOMForUnicodeEncodedFile'             # BOM-less UTF-8 is the repo convention; 5.1 path stays ASCII
        'PSUseSingularNouns'                        # names like Get-TicketWorktrees are public, shimmed call sites
        'PSUseShouldProcessForStateChangingFunctions' # internal helpers, not user-facing cmdlets
        'PSAvoidUsingEmptyCatchBlock'               # best-effort probes swallow a missing tool, a closed process, or an unreadable file; throwing would stop bootstrap and stop scripts
        'PSReviewUnusedParameter'                   # script parameters are read inside nested functions, and function parameters inside -Body scriptblocks, which this rule does not count; other parameters stay so callers and test doubles can pass them
        'PSUseApprovedVerbs'                        # Ensure-* and underscore helpers are internal names already called across dot-sourced scripts; none are exported cmdlets
        'PSUseSupportsShouldProcess'                # -WhatIf is a manual switch passed to child scripts, not the common parameter on an exported cmdlet
        'PSShouldProcess'                           # nested Stop-ProcessTree calls the parent script's $PSCmdlet.ShouldProcess; SupportsShouldProcess is on the script
        'PSAvoidUsingInvokeExpression'              # the service launcher runs a caller-built command string; there is no command object to invoke
        'PSUseUsingScopeModifierInNewRunspaces'     # the Start-Job scriptblock declares param() and receives values through -ArgumentList, the 5.1-safe pattern
    )
}
