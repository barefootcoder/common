# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Claude Helper Guide for Common Repository

## Core Architecture

This is a personal utilities repository containing:
- **myperl framework**: Modern Perl utility library with enhanced features (strict, warnings, autodie, utf8)
- **Personal scripts**: Collection of utility scripts in `/bin/`
- **Configuration files**: Shell, editor, and application configs in `/rc/`
- **Machine-specific code**: Host-specific configurations in `/local/`

### myperl Framework
The `myperl` module (perl/myperl.pm) provides:
- Automatic imports of common modules (strict, warnings, autodie, utf8, etc.)
- Utility functions: `title_case()`, `round()`, `expand()`, `prompt()`, `confirm()`
- Enhanced class system via `myperl::Classlet` with keywords like `rw`, `via`, `by`
- Script utilities via `myperl::Script` and `myperl::Pxb`

## Testing & Development Commands
- **Run test suite**: `t myperl` (runs all myperl tests)
- **Run specific test**: `t perl/myperl/t/<test_file>.t`
- **Install dependencies**: `bin/myperl-cpm myperl`
- **TDD workflow**: Write failing tests first, implement code, verify tests pass

## Code Style Guidelines
- **Languages**: Primarily Perl and Bash
- **Perl Style**:
  - Use Allman style
  - Use modern Perl features (5.14+)
  - Classes: CamelCase (Moose/CLASS)
  - Functions/variables: snake_case
  - Constants: ALL_CAPS
  - Error handling: die/fatal or try/catch (Syntax::Keyword::Try)
  - Imports: group by purpose, core first
- **Bash Style**:
  - Use Allman style
  - Define $ME for error reporting
  - Use functions for code organization
  - Document options with usage()
  - Use kebab-case for functions/commands
  - Use snake_case for variables

## Repository Distribution
This repository is part of a Syncthing share that propagates across all the
user's machines (Haven, Avalir, etc.).  There is no separate "deploy to
machine X" step -- pushing a commit on one machine and waiting for Syncthing
to catch up makes the change available everywhere.  Running `makeln` on a
target host applies any new symlinks, setup-script changes, dconf settings,
crontab updates, etc. relative to the synced repo state.

Because every machine mounts this same synced tree, three things bite agents
constantly:
- **Know which machine you are on.**  Run `aidoc/check-environment` (or at
  least `hostname`) before any host-specific action; if you are already on the
  target box, run commands directly instead of `ssh`-ing (often into yourself).
  When you genuinely `ssh` between boxes,
  the login shell is tcsh: use a `bash -s` heredoc, never inline-quoted
  commands.  Full rationale in the global `~/.claude/CLAUDE.md` "Remote Hosts
  (ssh)" section.
- **Other agents may be working in this tree right now** (on this machine or
  another).  The working copy can hold uncommitted changes that are not yours,
  and a file you read may change under you before you write it -- if an edit is
  rejected as stale, re-read and redo it rather than forcing it.  See "## Git
  Commits" for what this means when you commit.
- **The repo's paths are host-dependent, and Claude's config is symlinked.**
  Don't hardcode assumptions about `~/common`: on Haven/Avalir it is a symlink
  to `/export/proj/common`, but on quin it is a real directory Syncthing writes
  to directly.  Rather than guess, run `aidoc/check-environment` -- it reports
  the host plus your cwd/`~/common` symlink status (and whether the git base is
  sound).  Separately, Claude's own config (`CLAUDE.md`, `settings.json`,
  `keybindings.json`, `skills/`, ...) is git-tracked by living here in
  `conf/ai/claude/` and symlinked into `~/.claude/`.  Edit the repo copy: the
  Edit/Write tool refuses to write through a symlinked *file*, so `readlink -f`
  a `~/.claude/...` path to its real target.  Full map and the new-artifact
  rule: the `/x-claude-setup` skill.

## Key Files and Directories
- `/bin/t`: Comprehensive test runner with coverage, profiling, and parallel execution
- `/bin/myperl-cpm`: Dependency installer using App::cpm with cpanfile features
- `/bin/launch-perl`: Wrapper for invoking Perl scripts from environments that don't inherit the interactive `$PATH` (see "Launching Perl from constrained environments" below)
- `/perl/myperl.pm`: Core framework providing enhanced Perl environment
- `/perl/myperl/`: Framework modules (Classlet, Script, Pxb, etc.)
- `/cpanfile`: Dependency specifications with feature groups
- `/local/*/`: Host-specific configurations and scripts

## Launching Perl from constrained environments
When a Perl script will be invoked from somewhere that does *not* inherit
the user's interactive shell environment — cron jobs, MATE/X keybindings,
desktop launchers, systemd units, `.desktop` files, etc. — invoke it
through `~/bin/launch-perl` rather than relying on the script's own
shebang. A bare `#! /usr/bin/env perl` (or `/usr/bin/perl`) will pick up
system Perl, which is missing perlbrew-installed CPAN modules and will
fail in confusing ways (or silently, since these contexts usually
discard stderr).

`launch-perl` locates perlbrew's perl, sets up `PATH`, `PERL5LIB`, and
`local::lib`, and redirects stderr to `/tmp/launch-perl/<pid>.error` so
silent failures are still diagnosable.

Usage: `~/bin/launch-perl <script-name> [args...]` — the script name is
resolved via `$PATH` and `~/bin/`, so just pass the bare name.

Example: a MATE custom keybinding action should be
`/home/buddy/bin/launch-perl my-script arg1` rather than
`/home/buddy/bin/my-script arg1`.

## Development Workflow
When working with myperl code:
1. Use TDD: write tests in `perl/myperl/t/` first
2. Run `t myperl` to execute test suite
3. Install new dependencies via `bin/myperl-cpm <feature>`
4. Follow existing patterns in framework modules

## Git Commits
Commits go through the `/x-commit` skill, which owns the message format, line
wrapping, and AI-attribution rules.  Don't hand-craft commit messages or run
`git commit` directly — invoke `/x-commit` and let it handle formatting.

This is a shared tree that other agents may be editing concurrently (see
"## Repository Distribution"), so **stage only the specific files YOU changed
this session, by explicit path.**  Never `git add -A`, `git add .`, `git add
-u`, or `git commit -a`: those sweep up whatever else is dirty, including
another agent's in-flight work.  If `git status --porcelain` shows changes you
do not recognize, leave them unstaged.

And **do not pre-compute the commit before you are asked to make one.**  The
user gates every commit precisely so they can coordinate the several agents
working this tree at once -- which means other commits land *while* you would be
measuring, so any scope, staged state, or `git status` reading you gather ahead
of the go-ahead is stale before you finish.  When your work is done, summarize
it and stop; work out what to stage only once the user says "commit" (and then
only your own files, per above).

## Collaboration Style
- **"BE CREATIVE"**: Provide multiple high-level ideas with outside-the-box thinking
- **"BE SPECIFIC"**: Give explicit step-by-step instructions assuming no prior knowledge
- Ask clarifying questions when uncertain
- Don't assume the user is always right - they value your expertise
- Trust that the user can see the big picture

## User Technical Background
- **Programming**: Professional since 1987, Perl since 1996, strong OOP/TDD/systems design
- **Shell**: Uses tcsh interactively, scripts in bash (mid-2000s+)
- **Tools**: Experienced with git/GitHub, vim power user, prefers command-line when practical
- **System**: Linux user since mid-90s, decent CLI skills, minimal sysadmin experience
