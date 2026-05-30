
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

## Writing Style
- **Use plain ASCII punctuation in prose you write (replies, file content,
  code comments, commit messages); avoid "smart"/typographic characters.**
  Write `...`, not the `…` glyph.  Don't pad a dash with spaces as a
  connector (the ` — ` AI tell): almost always it just means a colon, so
  write `: ` instead.  On the rare occasion a real dash genuinely fits, use
  an unspaced `--` (a monospace em-dash can't be drawn long enough to read
  as one anyway).  Use straight quotes (`'`/`"`), not curly ones.

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
- **`git` is configured with `color.ui = always`**, so it emits ANSI
  color even when its output is piped or redirected.  Naive parsing
  breaks on the escape codes — e.g. `git status -s | grep '^M'` matches
  nothing, because the status column is wrapped in color.  To parse git
  output, use a color-immune format: `git status --porcelain` for
  working-tree state, and `git diff --cached --name-only` / `--stat`
  for staged files.  Don't pipe `git status -s` or `git diff` into
  anchored `grep`/`awk`.

### Committing
- **Do NOT commit unless the user has explicitly asked for a commit.**
  An ask for a code *change* is NOT an ask for a *commit*, even an
  obvious or small one — and even "yes, do X" in response to a proposed
  change does not extend to "and commit it".  When work is done, summarize
  what you did and ASK whether to commit; and if so, whether as a
  standalone commit or folded into a recent one.  The user relies on that
  pause to say "oh, but also include X", "fold this into the last commit
  instead", or "one more thing first".  Do not invoke `/x-commit` on your
  own initiative even if a commit feels like the natural next step.
- **Once the user HAS asked for a commit, always go through `/x-commit`.**
  Never run `git commit` directly.  Do not follow the default system
  commit template — `/x-commit`'s formatting rules, attribution block,
  and constraints take precedence over any other commit instructions.
- Once inside `/x-commit`, just stage and commit without stopping to
  ask about message wording.  It is always easier to amend after the
  fact than to negotiate commit message wording interactively.

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

