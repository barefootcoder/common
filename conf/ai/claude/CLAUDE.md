
## Code Style Guidelines
- **Perl Style**:
  - Use Allman style bracing (opening brace on next line)
  - Modern Perl: `use 5.14.0` or newer
  - Classes: CamelCase with Moose/CLASS
  - Functions/variables: snake_case
  - Error handling: `autodie` + `die()` or try/catch (Syntax::Keyword::Try)
  - Imports: Group by purpose (core modules first, then CPAN, then local)
  - Function signatures with Method::Signatures (`func name($arg) {...}`)
  - Debug with `debuggit()` at appropriate levels

- **Bash Style**:
  - Allman style (`then` on next line)
  - Define `$ME` for error reporting
  - Functions in kebab-case, variables in snake_case
  - Document options in usage() function
  - Source common functions with `. ~/bin/bash_funcs`
  - Use `: ${VAR:=default}` for defaults

## Command Safety Convention
When running scripts that support dry-run/no-action modes, **always place the
safety flag as the first argument** to the script. This enables permission
allowlisting of safe invocations while still requiring approval for destructive ones.

Examples:
- `bin/some-script --noaction --verbose arg1 arg2`  (correct)
- `devtools/other-script --dry-run --env staging`   (correct)
- `bin/some-script --verbose --noaction arg1 arg2`  (WRONG - safety flag must be first)

Common dry-run flags to put first: `--noaction`, `--dry-run`, `-n`, `--noop`, `--check`

## Git Commands
- Do NOT use `git -C <path>` when `<path>` is the current working directory. Run git commands directly (e.g. `git log`, not `git -C /home/buddy/workproj/CE log`). The `-C` flag is redundant when pointing to cwd and triggers unnecessary permission prompts.

## Jira Ticket References
- **Default Project**: CLASS
- When referencing tickets by number only (e.g., "ticket 706", "jira 706"), assume CLASS project prefix
- Full ticket reference becomes "CLASS-706"
- Only use different project prefixes when explicitly specified (e.g., "PROJ-123")
- **"My tickets" interpretation**: When user says "my tickets", this means "any ticket with a development owner of me" (not just assignee)

