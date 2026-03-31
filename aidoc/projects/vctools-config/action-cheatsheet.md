# VCtools Action Directive Reference

This is a reference for writing and reading VCtools config files (`vctools.conf`, `custom.conf`, etc.). VCtools configs define **info methods** (data gathering) and **commands** (user-facing actions), each composed of **action directives**.

## Job Types

### Info Methods

Info methods execute actions and capture their output. That output is substituted into other directives via `%name` expansion. Info methods are **always run, even in pretend mode**, so they must be non-destructive.

**Built-in info methods** (always available):

| Method | Returns |
|--------|---------|
| `%user` | Current user |
| `%status` | Output of `git status` |
| `%is_dirty` | True if working copy has uncommitted changes |
| `%has_staged` | True if there are staged changes |
| `%mod_files` | List of modified files |
| `%staged_files` | List of staged files |
| `%cur_branch` | Current branch name |
| `%branches` | List of local branches |
| `%remote_branches` | List of remote branches |
| `%tags` | List of tags |

**Built-in pseudo-info methods** (not defined as info blocks, but available via `%`):

| Method | Returns |
|--------|---------|
| `%running_nested` | True if currently executing as a nested command |
| `%me` | The `vc` command name |
| `%project` | Current project name |
| `%proj_root` | Project root directory |
| `%vc` | Version control system in use |
| `%Mainline` | Name of the mainline branch (e.g., `master`, `trunk`) |
| `%files` | Files passed as arguments to the command |

**Internal info method definition syntax:**

```
<info>
    status <<---
        git status
    ---
</info>
```

**Custom info method definition syntax:**

```
<CustomInfo trunk_version>
    Type = Str
    action <<---
        git fetch -q origin
        git show origin/trunk:etc/version.txt
    ---
</CustomInfo>
```

`Type` can be `Str` (scalar) or `ArrayRef` (list, one element per output line).

### Commands

Commands execute actions with output going to the user. If any action fails, execution stops, the user is informed, and remaining actions are listed for manual recovery.

**Custom command definition syntax:**

```
<CustomCommand feature-start>
    Description = This command creates a new feature branch
    Argument = branch_name          <the name of the feature branch>
    Verify = project
    Verify = clean
    Files = 0
    action <<---
        NEW_BRANCH="feature/" . %branch_name
        git checkout -b $NEW_BRANCH
    ---
</CustomCommand>
```

**Command header directives:**

| Directive | Purpose | Notes |
|-----------|---------|-------|
| `Description` | Human-readable description | Shown in help output |
| `Argument` | Named argument | Repeatable; creates `%argname` info method |
| `Verify` | Pre-condition check | `project` (must be in a VCtools project) or `clean` (no uncommitted changes) |
| `Files` | File argument count constraint | Optional. `0` = none, `1..` = at least one, `0..2` = zero to two |
| `<Trailing name>` | Trailing argument(s) | Block with `singular`, `description`, `qty` sub-directives |

The `Argument` directive format is: `Argument = name  <human-readable description>`

## Action Directive Types

Within an `action <<--- ... ---` block, each line is one action directive. Blank lines and lines starting with `#` are ignored. Comments may **not** appear on the same line as a directive.

### 1. Shell Directives

```
git branch
```

**Detection:** Any line not matching another directive type.
**Behavior:** Passed to the shell. Passes if exit code is 0; fails otherwise.

### 2. Code Directives

```
{ %trunk_version - 1 }
```

**Detection:** Starts with `{`, ends with `}`.
**Behavior:** Evaluated as Perl code (after expansions). Passes if the final expression is truthy; fails if falsy. Use sparingly -- prefer other directive types when possible.

### 3. Nested Commands

```
= publish
```

**Detection:** Starts with `= ` (equals, space).
**Behavior:** Invokes another VCtools command inline. VCtools is not respawned; command-line switches (pretend mode, etc.) pass through. This is the primary code-reuse mechanism.

### 4. Message Directives

```
> current branch is %cur_branch
```

**Detection:** Starts with `> ` (greater-than, space).
**Behavior:** Prints message to user. Always passes. Supports color expansions.

### 5. Confirmation Directives

```
? This could be dangerous.
```

**Detection:** Starts with `? ` (question mark, space).
**Behavior:** Prints message, prompts user for yes/no. Fails (aborts command) if user says no. Supports color expansions.

### 6. Fatal Directives

```
! Cannot continue; sorry.
```

**Detection:** Starts with `! ` (exclamation, space).
**Behavior:** Prints message in red, exits with failure. Typically used as the action in a conditional.

### 7. Env Assignments

```
STG_BRANCH="staging/" . %stg_branch
```

**Detection:** Contains `=` with **no surrounding whitespace** (i.e., `VAR=expr`, not `a = b`).
**Behavior:** Left side is the env variable name. Right side is a Perl expression. Always passes. The variable is available to all subsequent directives in the same command via `$VARNAME`.

### 8. Conditionals

```
%cur_branch ne %Mainline -> ! You must start on trunk.
```

**Detection:** Contains ` -> ` (space, arrow, space).
**Behavior:** Left side is a Perl expression (the condition). Right side is any action directive (including another conditional -- they can be chained). If condition is truthy, the action executes. If falsy, execution continues to the next line.

**Common patterns:**

```
# guard clause
%is_dirty -> ! You have uncommitted changes.

# conditional execution
$HAS_CHANGES -> git add %mod_files

# chained conditional
'$STASH' -> %is_dirty -> ! Cannot unstash; stuff is in the way.
```

## Expansion Types

Expansions are performed in this order on each directive:

### 1. Info Expansion (`%name`)

```
%cur_branch
```

A `%` followed by two or more alphanumeric characters. Replaced with the info method's value. Performed on **all** directive types. Handles quoting correctly when expanding into Perl expressions.

### 2. Env Expansion (`$NAME`)

```
$STG_BRANCH
```

A `$` followed by a name starting with a letter (two or more alphanumeric characters). Replaced with the env variable's value.

**Performed on:** nested commands, message directives, confirmation directives, fatal directives, and Perl expressions (right side of env assignments, left side of conditionals).
**Not performed on:** shell directives (the shell handles its own `$VAR` expansion), code directives.

**Note:** `$_FOO` and `$self` are not expanded as env vars. Use ALL_CAPS for env variable names.

### 3. PID Expansion (`$$`)

```
$$
```

Replaced with the PID of the current VCtools instance. Only performed on shell directives.

### 4. Color Expansions

```
*+Success!+*
```

Wraps text in terminal color codes. Performed on message directives and confirmation directives only.

| Syntax | Color |
|--------|-------|
| `*!text!*` | Bright red |
| `*~text~*` | Bright yellow |
| `*+text+*` | Bright green |
| `*-text-*` | Bright cyan |
| `*=text=*` | Bold |

## Config File Structure

### Include Directives

```
<<include ~/.vctools/custom.conf>>
```

Includes another config file inline. Supports `~` and `$ENV` expansion in the path.

### Block Structure

```
<git>...</git>              # VC-specific overrides
<Project name>...</Project> # Project definitions
<Policy name>...</Policy>   # Policy-specific overrides
<CustomInfo name>...</CustomInfo>       # Custom info method
<CustomCommand name>...</CustomCommand> # Custom command
```

### Typical Include Chain

1. `vctools.conf` (or `vctools.conf.<hostname>`) -- base config: VCtoolsDir, WorkingDir, project defs, includes VCtools' built-in git/svn configs
2. `custom.conf` -- shared custom commands and overrides
3. `CE-custom.conf` (optional) -- policy-specific overrides for work projects

[Created and submitted by AI: Claude]
