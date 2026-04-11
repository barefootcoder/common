---
name: x-consolidate-perms
description: Audit project-local Claude Code permissions and migrate appropriate ones to user scope
model: opus
disable-model-invocation: true
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep
---

# Consolidate Project-Local Permissions into User Scope

You are reviewing the current project's `.claude/settings.local.json` permissions
and migrating appropriate entries to the user-scope `~/.claude/settings.json`.

## Background

Claude Code permissions have three scopes (highest to lowest precedence):
- **Project local** (`.claude/settings.local.json`) -- private, per-repo
- **Project shared** (`.claude/settings.json`) -- committed, team-visible
- **User** (`~/.claude/settings.json`) -- global, all projects

Arrays (`allow`, `deny`) **merge** across scopes.  Deny always beats allow.

## Step 1: Read Both Files

1. Read `~/.claude/settings.json` to understand what is already at user scope.
2. Read the project's `.claude/settings.local.json` to see what needs review.

## Step 2: Understand the User Settings Organization

The `allow` list in `~/.claude/settings.json` is organized into groups
separated by blank lines.  **Preserve this ordering when adding entries.**

### Deny rules (`deny` array)

Two groups, separated by a blank line:

1. **Destructive `find` variants** -- flags that cause `find` to execute or
   delete: `-exec`, `-execdir`, `-ok`, `-okdir`, `-delete`.
2. **Destructive `curl` variants** -- flags that send data, upload files, or
   write to disk: `-X POST/PUT/DELETE/PATCH`, `-d`/`--data*`,
   `--upload-file`/`-T`, `-o`/`--output`/`-O`/`--remote-name`.

These deny rules exist because `find *` and `curl *` are broadly allowed (see
below), so the deny rules act as safety guards against their dangerous modes.

### Allow rules (`allow` array), in order

1. **Core tools** -- `Grep`, `Glob`, `Read` (blanket allows for the built-in
   readonly tools).

2. **Skills and skill support** -- Bash commands for user-level skill scripts
   (e.g. `~/.claude/skills/` paths) and CLI tools those skills invoke (e.g.
   `jira`).  Paths must use full absolute paths (not `~/`) because Bash
   patterns match the literal command string.

3. **MCP tool permissions** -- `mcp__*` entries for MCP servers defined at
   user scope (Google Sheets, Playwright, etc.).

4. **Web** -- `WebSearch` followed by `WebFetch(domain:...)` entries for
   general-purpose development domains (docs, reference sites).

5. **Safe-but-broad utilities** -- Simple, always-readonly commands that are
   useful in any project: `ls`, `cat`, `echo`, `wc`, `test`, `grep`, `ps`,
   `pgrep`, `ping`.

6. **Deny-guarded commands** -- Commands that are broadly allowed but have
   corresponding deny rules for their dangerous modes: `find *`, `curl *`.

7. **Perl (safe only)** -- Only guaranteed-safe perl commands: `perl --version`,
   `perl -v`, `perldoc *`.  **Never allow `perl *`, `perl -e *`, or any form
   that can execute arbitrary code.**

8. **Perlbrew (readonly subcommands)** -- Only informational subcommands:
   `list`, `available`, `info`, `version`, `self-info`, `env`, `lib list`,
   `which`.  **Never allow broad `perlbrew *` or write operations like
   `install`, `install-cpanm`, `switch`, `use`.**

9. **Git (readonly subcommands)** -- Two sub-groups:
   - Purely readonly subcommands (the subcommand itself can never write):
     `status`, `log`, `diff`, `show`, `blame`, `shortlog`, `describe`, `grep`,
     `rev-parse`, `rev-list`, `ls-files`, `ls-tree`, `ls-remote`, `cat-file`,
     `whatchanged`, `count-objects`, `for-each-ref`, `name-rev`.
   - Safe variants of mixed subcommands (explicit readonly flags):
     `reflog show`, `stash list`, `remote` (bare), `remote -v`,
     `remote show`, `config --list`, `config --get`, `config --get-all`,
     `branch --list`, `tag --list`, `tag -l`.
   **Never allow broad `git *` -- subcommands like `push`, `reset`, `clean`
   are destructive.**

10. **Dev tools** -- Cross-project development utilities: `t *` (test runner),
    `bin/t *`, `sed *`, `claude mcp *`, `aidoc-locate *`, `go version *`.

11. **System debugging** -- Readonly system inspection commands: `journalctl`,
    `dmesg`, `sensors`, `systemctl status`, `last`.

12. **AWS (readonly)** -- Only read operations like `aws ssm get-document`,
    `aws ssm list-documents`, `aws ssm describe-*`.  **Never allow
    `aws configure *` (it can write to `~/.aws/config`).**

## Step 3: Categorize Each Project-Local Entry

Apply the decision framework below to every entry in the project-local file.

### Move to user scope if the entry is:
- A general-purpose readonly command (e.g. `ls`, `wc`, `ps`)
- A development tool used across multiple projects (e.g. `perldoc`, `git log`)
- A WebFetch domain for general reference sites (e.g. metacpan.org, github.com)
- An MCP tool permission for a user-scope MCP server
- A skill-related command for a user-level skill

### Keep in project-local if the entry is:
- A project-specific script (e.g. `./parse-nakama-alerts.pl`)
- A task-specific or niche WebFetch domain
- A command with project-specific paths (e.g. `/export/proj/foo/bin/tool`)
- Something the user should be prompted about in other contexts

### Remove entirely if the entry is:
- Redundant (subsumed by a broader rule already at user scope, e.g.
  `echo $CEROOT` is covered by `echo *`)
- Already covered by a blanket tool allow (e.g. specific `Read(//path/**)`
  entries when `Read` is already globally allowed)
- One-off cruft from auto-approved multi-line commands (e.g. `while IFS=`,
  `do echo`, `done` as separate entries)
- A command that is too dangerous to auto-approve anywhere (e.g. `perl *`,
  `sudo *`, `rm -rf *`)

### Never add to user scope:
- `perl *`, `perl -e *`, or any `perl` variant that can execute arbitrary code
- `python *`, `python3 *`, or any Python variant (same reason)
- `sudo *` or any privileged command
- `ssh *` (too broad -- specific hosts can go in project-local if needed)
- `gpg *`, `chmod *`, or other commands that write to disk in hard-to-predict ways
- Broad tool wildcards for tools with destructive subcommands (`git *`,
  `perlbrew *`, `aws *`)

## Step 4: Present Your Audit

Present the categorization to the user as a table or grouped list showing:
- Each entry from the project-local file
- Your recommendation: **move**, **keep**, or **remove**
- Brief reason

Wait for the user to review and approve before making any changes.

## Step 5: Apply Changes

After user approval:

1. **Add new entries to user scope**: Edit `~/.claude/settings.json` and insert
   entries into the correct group (see organizational structure above).  Maintain
   the blank-line separation between groups.

2. **Handle home directory paths**: For any Bash entry containing `/home/buddy/`
   or `/home/bburden/`, add both variants so the file works on all machines.

3. **Clean up the project-local file**: Remove entries that were moved or are
   now redundant.  The project-local file should only contain entries that are
   genuinely project-specific.

## Cross-Machine Portability

The user settings file (`~/.claude/settings.json`) is shared across machines
where the username may differ (`/home/buddy/` vs `/home/bburden/`).  All
entries must be written to work on both machines.

### Path strategies by context

| Context | Strategy | Example |
|---------|----------|---------|
| `additionalDirectories` | Use `~/` | `~/common/aidoc` |
| `Read`/`Edit` patterns | Use `~/` | `Read(~/common/aidoc/**)` |
| Hook commands | Use `~/common/` | `~/common/conf/ai/devtools/script` |
| `statusLine` command | Use `~/` | `bash ~/.claude/statusline-command.sh` |
| Bash permission patterns | Full absolute paths, **both variants** | See below |
| MCP server paths | Machine-specific (not portable) | Leave as-is |

### The `~/common/` symlink

Both machines have `~/common/` symlinked to the actual common repository
checkout.  **Always use `~/common/` instead of the absolute repo path** in
hooks, `additionalDirectories`, and anywhere else that supports tilde
expansion.

### Bash permission patterns (no tilde)

Bash patterns match the literal command string that Claude generates.  Since
Claude resolves paths to absolute form, `~/` in a Bash pattern will not match
`/home/buddy/...`.  For Bash entries with home directory paths, include both
username variants:

```json
"Bash(/home/buddy/.claude/skills/x-take-ticket/scripts/ticket-preflight)",
"Bash(/home/bburden/.claude/skills/x-take-ticket/scripts/ticket-preflight)",
```

## Syntax Rules

- **Use space syntax, not colon syntax.**  Write `Bash(git log *)`, not
  `Bash(git log:*)`.  The colon form is deprecated.
- **`*` matches zero or more** after a space (word boundary).  `Bash(cmd *)`
  matches both `cmd` (bare) and `cmd arg1 arg2`.
- **Home directory paths in Read/Edit patterns** support `~/` and should use
  it for portability.
- **`additionalDirectories`** also supports `~/`.

## Anti-Patterns to Avoid

- **Don't add broad wildcards for powerful commands** -- `perl *`, `git *`,
  `ssh *`, `aws *` are too dangerous.  Use specific subcommands.
- **Don't convert colon syntax in project-local files without being asked** --
  focus on the migration task, not reformatting what stays behind.
- **Don't reorder existing groups** -- add to the correct group in place.
- **Don't remove entries from project-local without understanding them** --
  if you are unsure whether something is project-specific, ask the user.
- **Don't forget the deny guards** -- if you add a new broadly-allowed command
  that has dangerous modes (like `find` or `curl`), add corresponding deny
  rules too.
