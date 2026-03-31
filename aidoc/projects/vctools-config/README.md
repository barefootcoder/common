# VCtools Config

## Overview
Configuration and helper scripts for [VCtools](~/proj/VCtools), a personal version-control workflow framework. VCtools provides a `vc` command that wraps git (and formerly svn) with custom commands, info methods, and project awareness. This project covers the configuration files that define custom commands/overrides and the companion scripts that those commands call.

## Repository Files

### Configuration
- `rc/vctoolsrc` - tcsh shell integration: aliases, completions, and VC-shell-mode setup
- `vctools/vctools.conf` - default VCtools config (all machines): VCtoolsDir, WorkingDir, project defs, includes
- `vctools/custom.conf` - shared custom commands and overrides (the bulk of customization)
- `vctools/CE-custom.conf` - policy overrides for CE (work) projects

### Host-Specific Configs
- `vctools/vctools.conf.avalir` - Avalir-specific config (adds workproj dir, CE conf)
- `vctools/vctools.conf.caemlyn` - Caemlyn-specific config
- `vctools/vctools.conf.braavos` - Braavos-specific config
- `vctools/vctools.conf.haven` - Haven-specific config
- `vctools/vctools.conf.cibola` - Cibola-specific config
- `vctools/vctools.conf.absalom` - Absalom-specific config
- `vctools/vctools.conf.quin` - Quin-specific config
- `vctools/vctools.conf.zadash` - Zadash-specific config
- `vctools/vctools.conf.vagrant-sandbox` - Vagrant sandbox config

### Helper Scripts (bin/)
Scripts called by VCtools custom commands or shell aliases:

#### Git Helpers (called by custom commands)
- `bin/git-helper-stat` - enhanced status display (used by `stat-plus` / `st`)
- `bin/git-helper-log` - enhanced log display (used by `vlog` alias)
- `bin/git-helper-branch` - enhanced branch display (used by `vbranch` / `branch` alias)
- `bin/git-helper-local-commits` - list unpushed commits (used by `%local_commits` info method)
- `bin/git-helper-mainline` - determine the mainline branch name
- `bin/git-savetimes` - save/restore file mtimes across git operations (used by `my-sync`, `my-push`, stash commands)
- `bin/git-find-changesets` - find changesets (used by `vfc` alias)
- `bin/git-unstash-recover` - recover from conflicted unstash (used by `unstash-conflict-recover`)

#### Code Quality
- `bin/checktabs` - check for tabs in files (used by `chktabs` command and `tfix` alias)
- `bin/vcpatchws` - patch whitespace issues (used by `tfix` alias)

#### Search
- `bin/vgrep` - project-aware grep (used by `vg`, `vgl`, `vgc`, `vgt` aliases)

#### Other Git Utilities (not directly called by VCtools but related)
- `bin/git-grep-history` - search git history
- `bin/git-grep-all` - grep across all branches
- `bin/git-all-commits` - list all commits
- `bin/git-line-hist` - line-level history
- `bin/git-creator` - find who created a file
- `bin/git-newest-file` - find newest file
- `bin/git-latest-files` - find latest modified files

## External Reference
- `action-cheatsheet.md` - VCtools action directive syntax guide (copied from `~/proj/VCtools/doc/`)

## Key Concepts

### Config File Structure
VCtools configs use an Apache-style block syntax with `<<include>>` directives for modularity:
- **Default config** (`vctools.conf`) sets basics and includes VCtools' built-in git/svn configs, then includes `custom.conf`
- **Host-specific configs** (`vctools.conf.<hostname>`) override the default when present, adding host-specific WorkingDirs or includes
- **Custom config** (`custom.conf`) holds shared custom commands and command overrides
- **Policy configs** (`CE-custom.conf`) provide per-policy command variants (e.g., CE work projects use different sync/stage/merge behavior)

### Custom Commands (in custom.conf)
Major command groups:
- **Sync/Push**: `my-sync`, `my-push` -- wrap standard sync/push with mtime preservation via `git-savetimes`
- **Stash suite**: `my-stash`, `my-unstash`, `stash-p`, `stash-files`, `stash-search`, `stash-drop`, `stash-check`, `stash-identify`, `unstash-force`, `unstash-conflict-recover`, `just-a-sec` -- named stash management with timestamp preservation
- **Amend/Rebase**: `stg-amend`, `amend-local`, `split-amend` -- interactive history rewriting with safety checks
- **Branch ops**: `merge`, `force-align`, `reset-published`, `find-unmerged-commits`, `branch-contains` -- branch management with publish-safety
- **Misc**: `stat-plus`, `rebranch`, `clean`, `testclean`, `ls-mods`, `reset-symlinks`, `push-some`, `commit-filedate`, `commit-date`, `changed-files`, `previous-version`, `set-upstream`

### Shell Integration (vctoolsrc)
When `vcd` enters a project, it sets `$VCTOOLS_SHELL`, activating a full set of short aliases (`st`, `sync`, `commit`, `branch`, `vd`, `vlog`, etc.). The `vgrep` aliases (`vg`, `vgl`, `vgc`, `vgt`) provide project-scoped searching.

### Action Directive Syntax
See `action-cheatsheet.md` for the full reference. Key directive types: shell commands, code directives (`{...}`), nested commands (`= cmd`), messages (`>`), confirmations (`?`), fatals (`!`), env assignments, and conditionals (`condition -> action`). Expansions: `%info`, `$ENV`, `$$` (PID), and color (`*+green+*`).

## Development Patterns
- Host-specific configs copy the default config structure and add/change only what differs
- Custom commands use `= nested-command` for code reuse (e.g., `safe-stash-push`/`safe-stash-pop`)
- Destructive operations use `?` confirmation directives and `!` fatals for safety
- The `chktabs` command is called as a pre-check by several commit-related commands
- Env vars set in one action are available to subsequent actions in the same command
- Conditions commonly check `%is_dirty`, `%cur_branch`, and `%num_local_commits`

## Troubleshooting
- **"no ssh connectivity!"** -- Most sync/push/merge commands require an active ssh-agent; run `ssh-add` first
- **Stash conflicts** -- Use `vc unstash-conflict-recover <id>` to recover, or `vc unstash-force <id>` to force-apply
- **Tab violations** -- `vc chktabs` checks for tabs; `tfix` alias auto-fixes them
- **Spurious typechanges** -- `vc reset-symlinks` reverts typechange modifications (often caused by Dropbox)
- **Completion not working** -- `vcresrc` alias re-sources vctoolsrc; completions are auto-generated by `vc shell-complete`

[Created and submitted by AI: Claude]
