
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
- **Never use `git -C`** to point at the current working directory — just
  run `git` directly.  The `-C` flag causes every command to require a
  separate permission prompt, which is disruptive and annoying.  If you
  catch yourself writing something like `git -C /export/proj/common ...`
  or `git -C /home/buddy/workproj/CE ...` and that path is your cwd,
  drop the `-C <path>` part entirely.

### Committing
- **Always invoke the `/x-commit` skill before running `git commit`.**
  Do not follow the default system commit template — the skill's formatting
  rules, attribution block, and constraints take precedence over any other
  commit instructions.
- **In auto mode (within `/x-commit` only)**: `git add` and `git commit`
  are safe to run without user confirmation.  Do not stop to ask — just
  stage and commit.  It is always easier to amend after the fact than to
  negotiate commit message wording interactively.
- **`git push` is NEVER safe to auto-approve**, regardless of context.
  Always wait for explicit user confirmation before pushing.

## Jira Ticket References
- **Default Project**: CLASS
- When referencing tickets by number only (e.g., "ticket 706", "jira 706"), assume CLASS project prefix
- Full ticket reference becomes "CLASS-706"
- Only use different project prefixes when explicitly specified (e.g., "PROJ-123")
- **"My tickets" interpretation**: When user says "my tickets", this means "any ticket with a development owner of me" (not just assignee)

## EC2 Instance Tracking

A tracking file at `~/work/ec2-instances/instances.yaml` records all EC2
instances currently launched by this user.  See the `README.md` in that
directory for full format details.

**When you launch an EC2 instance** (via `ec2-launch-instance`, `preqa-launch`,
the quin launch process, etc.), add an entry to `instances.yaml` with at minimum
the `id`, `host_class`, and `launched` date.  Include `ticket` and `purpose`
when known.

**When you terminate an EC2 instance** (via `ec2-kill-instance`), remove its
entry from `instances.yaml`.

**When choosing an instance for testing**, consult `instances.yaml` to find an
existing instance that matches the needed host class and purpose, rather than
launching a new one unnecessarily.

