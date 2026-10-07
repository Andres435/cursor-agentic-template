# Doc-sync registry: what the docs must keep saying, and which docs must move with which code.
#
# Read by Assert-AgenticFlow.ps1 (section 12b, Claims) and Assert-DocSync.ps1 (section 14,
# CoChange). Data only: Import-PowerShellDataFile runs no code. Paths are repo-relative with
# forward slashes; globs use PowerShell -like, where * also crosses folders.
#
# Claims -- a workflow fact the docs state. Each one may have:
#   Anchor  @{ File; Pattern }   the code that makes the fact true. If the pattern disappears
#                                (the gate was renamed or removed), the claim fails until it is
#                                updated or retired -- a code change cannot leave its prose behind.
#   Require @( @{ File; Pattern } )   text that must be present in a file.
#   Forbid  @( @{ Pattern; In; Except } )   text that must not appear in any file matching In
#                                (default: every doc) unless it matches Except.
# There is no waiver for a claim: changing what is true means editing this file, in the diff.
# A project overlay adds its own claims (its stack, its tracker) below the core ones.
#
# CoChange -- when a file matching When changes (Ignore excluded), at least one file matching
# Touch must change in the same branch. Otherwise a commit in the branch carries the trailer
#   Docs-Unaffected: <Id>: <reason of 15+ characters>
# (or without "<Id>:" to cover every rule). Each waiver is printed as [INFO] in the CI log.

@{
    Claims = @(
        @{
            Id      = 'branch-mode-three-chats'
            Why     = 'Branch mode is /start-ticket (plan + build), /review-changes, /complete-task. USER-MANUAL owns the counts.'
            Require = @(
                @{ File = 'USER-MANUAL.md'; Pattern = '(?i)branch mode is three chats' }
            )
            Forbid  = @(
                @{ Pattern = '(?i)\btwo chats\b' }
                @{ Pattern = '(?i)\b(three|four) chats\b'; Except = @('USER-MANUAL.md', '_shared/glossary.md') }
            )
        }
        @{
            Id     = 'close-requires-drive'
            Why    = 'Close fails a frontend-repo ticket whose change touches a uiGlobs file until the user confirms a Drive passed (stackSmoke Tested).'
            Anchor = @{ File = 'scripts/ticket/Assert-TicketArtifacts.ps1'; Pattern = 'function Test-UiEvidence' }
            Forbid = @(
                @{ Pattern = '(?i)does not block close|not required to close|close still works if you skip|never blocks close|close never needs it' }
            )
        }
        @{
            Id      = 'lane-term'
            Why     = 'A lane is one dispatched subagent run; manifest lanes counts them per tier.'
            Require = @(
                @{ File = '_shared/glossary.md'; Pattern = '(?m)^\| Lane \| One dispatched subagent run' }
                @{ File = '_shared/model-routing.md'; Pattern = 'A lane is one dispatched subagent run' }
            )
            Forbid  = @(
                @{ Pattern = '(?i)one lane is one contiguous run' }
            )
        }
        @{
            Id     = 'plugin-commands-empty'
            Why    = 'Every slash entry is a skill; commands/ holds only _README.md.'
            Anchor = @{ File = '.claude-plugin/plugin.json'; Pattern = '"commands":\s*\[\s*\]' }
            Forbid = @(
                @{ Pattern = '(?i)keeps the shims that are not skills|commands. is the exception . leave it explicit' }
            )
        }
        @{
            Id     = 'digest-does-not-prestate-gate'
            Why    = '/start-ticket reports the artifacts gate in chat after it runs; a plan never claims it passed.'
            Forbid = @(
                @{ Pattern = '\*\*Artifacts gate:\*\* PASS' }
            )
        }
        @{
            Id     = 'mcp-servers-pinned'
            Why    = 'npx -y runs fresh package code holding the user''s tokens; a server version moves only in a reviewed commit.'
            Forbid = @(
                @{ Pattern = '@latest\b'; In = @('mcp.json', 'adapters/*/mcp.json') }
            )
        }
        @{
            Id      = 'verdict-rules'
            Why     = 'Findings decide the verdict; close fails while a stamp records a Blocker or Major.'
            Anchor  = @{ File = 'scripts/ticket/lib/ManifestFields.ps1'; Pattern = 'function Get-VerdictFindingConflict' }
            Require = @(
                @{ File = '_shared/severity-and-output.md'; Pattern = '(?m)^### Verdict rules' }
                @{ File = 'skills/review-changes/playbooks/review-changes.md'; Pattern = '\*\*Fix loop\.\*\*' }
                @{ File = 'USER-MANUAL.md'; Pattern = 'close fails while a review stamp still records one' }
            )
        }
        @{
            Id      = 'push-gates-ticket-branches'
            Why     = 'A product-branch push that names a ticket with a manifest runs Assert-TicketArtifacts -Phase prepush; product pushes are not untouched.'
            Anchor  = @{ File = 'hooks/core/push-gate.js'; Pattern = 'function runPrepush' }
            Require = @(
                @{ File = 'skills/prep-pr/playbooks/prep-pr.md'; Pattern = '-Phase prepush' }
            )
            Forbid  = @(
                @{ Pattern = '(?i)product pushes? pass(es)? untouched|only when pushing (this|a) workflow (folder|clone)' }
            )
        }
        @{
            Id      = 'git-hooks-match-powershell'
            Why     = 'Claude runs the commit guard and the push gate for the PowerShell tool too, through one git-guard.js process.'
            Anchor  = @{ File = 'adapters/claude/hooks/hooks.json'; Pattern = '"matcher":\s*"Bash\|PowerShell"' }
            Require = @(
                @{ File = 'adapters/claude/README.md'; Pattern = 'git-guard\.js' }
            )
        }
    )

    CoChange = @(
        @{
            Id     = 'ticket-gates'
            Why    = 'A change to what close/start/implement check, or to a stamp script, changes what developers must do.'
            When   = @('scripts/ticket/Assert-TicketArtifacts.ps1', 'scripts/ticket/lib/*.ps1', 'scripts/ticket/Set-*.ps1', 'scripts/ticket/Get-*.ps1')
            Touch  = @('_shared/ticket-artifacts.md', 'USER-MANUAL.md', 'README.md', 'scripts/ticket/doc-claims.psd1', 'skills/*/playbooks/*.md')
            Ignore = @('*.Tests.ps1', 'scripts/ticket/fixtures/*')
        }
        @{
            Id     = 'hooks'
            Why    = 'Hook behavior is documented per IDE adapter and in the hook test catalog.'
            When   = @('hooks/core/*.js', 'hooks/git-hooks/*', 'hooks.json', 'adapters/*/hooks/*.js', 'adapters/*/hooks/hooks.json')
            Touch  = @('adapters/*/README.md', 'hooks/tests/README.md', 'scripts/ticket/doc-claims.psd1')
            Ignore = @('hooks/tests/*', 'adapters/*/hooks/tests/*')
        }
        @{
            Id     = 'lifecycle-playbooks'
            Why    = 'The ticket commands are what USER-MANUAL and the command catalog describe.'
            When   = @('skills/start-ticket/*', 'skills/implement/*', 'skills/review-changes/*', 'skills/complete-task/*', 'skills/prep-pr/*', 'skills/address-pr-comments/*', 'skills/peer-review/*')
            Touch  = @('USER-MANUAL.md', 'commands/_README.md', '_shared/glossary.md', '_shared/ticket-artifacts.md', 'scripts/ticket/doc-claims.psd1')
            Ignore = @()
        }
        @{
            Id     = 'workflow-gates'
            Why    = 'A new or changed repo gate belongs in the maintainer docs.'
            When   = @('scripts/ticket/Assert-AgenticFlow.ps1', 'scripts/ticket/Assert-DocSync.ps1', 'scripts/Assert-DocLinks.ps1', 'scripts/Assert-DocBudget.ps1', 'scripts/ticket/doc-claims.psd1')
            Touch  = @('README.md', 'TEMPLATE.md', '_shared/glossary.md')
            Ignore = @()
        }
    )
}
