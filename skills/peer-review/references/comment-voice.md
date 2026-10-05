---
name: peer-review-comment-voice
description: Voice rules and examples for /peer-review comments. Load before drafting any comment text.
keywords: peer review, comment voice, short, human, no severity
---

# Comment voice

Posted comments must read as if **the user** wrote a short note after reading the change. Not a
review bot. Not a findings list.

Load this file before drafting `Comment to post` text.

## Posted text

- 1–3 short sentences. One ask or observation.
- Explicit: name the type, method, folder, or behavior. No “this” with no noun.
- Show you understood the change (“this is doing X for Y, but…”).
- No severity labels: never Blocker, Major, Minor, Nit, finding, must-fix, or emoji.
- No convention citations (`per dotnet-overlay`, `per ADR-12`, `per review-protocol`).
- No template openers on every comment (`I noticed`, `Please consider`, `Nit:`, `Can we`).
- Contractions are fine. First person is fine when it sounds natural (`I'd put this…`, `I'm not seeing…`).
- Do not paste code blocks or diffs into the comment.

The chat draft may include a private `Why` line for the user. That line is **not** posted.
`Comment to post` is the posted body verbatim.

## Good (post this)

- "I'd put this next to the other loan types in `Services/Loans/`. The `Tds` prefix is already in the project name."
- "This still keys off `loanId`, but the ticket's waive path is supposed to use `streamID`."
- "`HasBalance` reads like a boolean, but it returns the amount. `GetBalance` would match how `LoanAccountResolver` names this."

## Bad (never post)

- "**Major** — Type naming violates no-module-prefix: `TdsLoanCreationService` should be `LoanCreationService`."
- "Per coding conventions, new types must live under `Services/{DomainArea}/`."
- "Please consider refactoring this for maintainability and readability."
