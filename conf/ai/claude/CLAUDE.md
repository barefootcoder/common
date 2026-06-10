
## Language Selection
When you have a choice of language for a script, helper, or glue code that will
live in my repos, pick by this preference order.  This is about what I want to
read and own in my codebase, not about what's easiest for you to write.

1. **Perl** -- my first choice and primary language.  Elegant when written well,
   and the language I read most fluently.  Default here unless there's a real
   reason not to.
2. **Bash** -- a solid second.  Ugly, but I read it easily.  Good for orchestration
   and glue.
3. **JavaScript** -- acceptable.  I read it only so-so, but well enough to get by.
4. **Specialty languages for specialty problems** -- Ruby, Rust, Go, etc. are fine
   *when the problem is genuinely a much better fit for them* and the resulting code
   is substantially simpler than it would be in Perl/bash.  I may not read them
   well, but past a certain point that simplicity is worth more than my fluency.
   Don't reach for them for general problems that Perl or bash handle fine.
5. **DSLs where they're the right tool** -- I'm fluent in SQL and the Excel/Google
   Sheets formula language.  Use them when they're genuinely the right choice; they
   just rarely are for a general-purpose problem.
6. **Java** -- hideous.  Avoid unless absolutely necessary.
7. **Python** -- anathema.  Do NOT use it, ever, for anything that lands in my repos
   -- not helpers, not glue, not "you'll never have to maintain it" throwaway code.
   This is a hard rule, not a mild preference: checking in Python leaves me feeling
   slimy even when I never wrote it and never run it directly.  It is not a
   capability gap (Python would probably give you *less* trouble) -- which is rather
   the point.  When something needs JSON/data munging, reach for Perl with core
   modules (e.g. `JSON::PP`, core since 5.14, so no CPAN or launch-perl needed)
   or bash plus standard tools.

Before introducing any language not already used in the relevant repo, confirm
with me first.

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

## Asking Questions (AskUserQuestion)
Before calling AskUserQuestion, always summarize your findings and the context
for the question in normal response text first.  Never let the dialog be the
only communication in a turn: the question UI has a known rendering bug where
it can cover or truncate the text immediately preceding it, and option
descriptions are too cramped to carry full context on their own.  A short
prose recap right before the dialog means that even when the rendering
glitches, at worst one line is lost instead of the whole explanation.

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

### Syncthing-shared repositories
Several of these repos (everything under `/export/proj`, which includes
`~/common`) are propagated between machines by Syncthing, NOT by a git
remote.  That makes the object store racy: a peer's commit can arrive
ref-first (`refs/heads/master` syncs before its loose objects), so `git`
here reports `bad object HEAD` / `fatal: bad object` even though nothing
is actually corrupt.
- This is a sync lag, not corruption.  Recover by forcing a Syncthing
  rescan on the machine that *made* the commit:
  `syncthing-rescan --path <repo>/.git` (it wraps the rescan `POST` so it
  doesn't hit the `curl -X POST` deny rule -- never poke the Syncthing
  REST API with a raw `curl`).  Then wait for the objects to arrive.
- **Never `git gc` / `prune` / `repack`** on these repos to "fix" such a
  problem: loose objects that haven't synced yet may be the only copy, and
  gc will delete them.  `/x-commit` now gates on this and rescans after
  committing.

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

## Remote Hosts (ssh)
**First, orient yourself.**  In a repo that ships one (`common` and `CE` both
do), run `aidoc/check-environment` -- it reports which box you are on, whether
your cwd and `~/common` are symlinks (and to where), and whether the git base is
sound.  Otherwise just run `hostname`.  Either way the point is the same: these
hosts share `~/common` (and more) over Syncthing, so the filesystem looks
identical everywhere and it is easy to lose track of which box you are on.  If
you are already ON the target host, run the command directly -- do NOT `ssh
haven` from Haven (it loops back into yourself over SSH and drags you through the
quoting trap below for nothing).

When you genuinely are on a different box: the login shell on my hosts (Haven,
Avalir, etc.) is **tcsh**, so a bare `ssh host '<command>'` runs your command
under tcsh, which chokes on bash syntax (`$(...)`, `VAR=val`, `2>&1`, heredocs,
`for`/`if` blocks, etc.).  And `ssh host bash -lc '<command>'` does NOT rescue
you: your *local* shell strips the quotes before `ssh` ever runs, so `ssh`
forwards the bare words and the *remote* tcsh re-parses them -- two shells chew
the command in turn, and piling on more quotes is just whack-a-mole.

**Use a `bash -s` heredoc by default** for anything with a pipe, semicolon,
redirect, loop, or more than a word or two of argument:
```bash
ssh host bash -s <<'EOF'
for f in foo bar; do something "$f"; done
EOF
```
The single-quoted `<<'EOF'` keeps your local shell off the body, and `bash -s`
feeds it to bash (not tcsh) verbatim on the far side: no quoting horrors,
multi-line for free.  A single trivial command inline (`ssh host uptime`) is
fine; the instant you need shell syntax, go straight to the heredoc.
Interactive `ssh host` and manual `ssh host my-alias` are unaffected --
this only bites when *you* send a shell command.

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

