# PSScriptAnalyzer settings for scripts/. CI fails on Error; Warning stays advisory.
# Each exclusion names why the rule does not fit these CLI scripts.
@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'                     # launchers and gates print to the console on purpose
        'PSUseBOMForUnicodeEncodedFile'             # BOM-less UTF-8 is the repo convention; 5.1 path stays ASCII
        'PSUseSingularNouns'                        # names like Get-TicketWorktrees are public, shimmed call sites
        'PSUseShouldProcessForStateChangingFunctions' # internal helpers, not user-facing cmdlets
    )
}
