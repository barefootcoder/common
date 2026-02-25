# myperl Framework

## Overview

The myperl framework is a personal Perl utility library that provides a modern, batteries-included environment for writing scripts and modules. It handles boilerplate (strict, warnings, utf8, common imports) so scripts can focus on their actual logic.

## Task Guides

Pick the guide that matches what you're doing:

### [Writing a Pxb Script](writing-pxb-scripts.md)
The most common task. Covers creating scripts that run external commands using `sh()`. Includes the template workflow, `opts` reference, `sh()` reference, and all available functions.

**Start here if**: you need to write a new script in `bin/`, or understand how existing Pxb scripts work.

### [Modifying myperl Itself](modifying-myperl.md)
For adding features, fixing bugs, or extending the myperl framework modules. Covers the module architecture, testing workflow (TDD required), where different types of changes go, and the test helper API.

**Start here if**: you need to add a utility function, change how imports work, extend Script/Pxb/Classlet, or fix a bug in the framework.

### Writing a Pure-Perl Script (myperl::Script)
For scripts that don't shell out to external commands. Use `myperl::Script` instead of `myperl::Pxb`:

```perl
#! /usr/bin/env perl

use myperl::Script;
use autodie ':all';
```

This gives you `$ME`, `%OPT`, `opts`, `fatal`, `usage_error`, `color_msg`, and the full myperl import set — but not `sh()`, `path()`, `file()`, etc. See the [Pxb script guide](writing-pxb-scripts.md) for `opts` syntax and common patterns, which are identical.

## Quick Reference

### Repository Layout
- `perl/myperl.pm` — core framework module
- `perl/myperl/Script.pm` — command-line script base (`$ME`, `%OPT`, `opts`, `fatal`)
- `perl/myperl/Pxb.pm` — command execution layer (`sh()`, `shw()`, path utilities)
- `perl/myperl/Classlet.pm` — enhanced class system (`rw`, `via`, `by`)
- `perl/myperl/Declare.pm` — declarative syntax extensions (MooseX::Declare integration)
- `perl/myperl/Template.pm` — template processing utilities
- `perl/myperl/Menu.pm` — interactive `menu()` function
- `perl/myperl/Google.pm` — Google API integration utilities
- `perl/myperl/t/` — test suite
- `perl/myperl/t/Test/myperl.pm` — test helper module
- `templates/pxb-script` — **start here** when creating any Pxb script
- `bin/t` — test runner (`t myperl` runs all tests)
- `bin/myperl-cpm` — dependency installer

### Running Tests
```
t myperl                          # run all myperl tests (~4 seconds)
t perl/myperl/t/specific.t       # run one test file
t -v myperl                       # verbose output
t -h                              # all testing options
```

### Installing Dependencies
```
bin/myperl-cpm myperl             # install core dependencies
bin/myperl-cpm <feature>          # install optional feature group (see cpanfile)
```

### Code Style
- **Allman style bracing** (opening brace on its own line)
- **snake_case** for functions and variables
- **CamelCase** for class/package names
- **ALL_CAPS** for constants
- Helper subs at the bottom of the script
- Group imports: `myperl::Pxb` + `autodie` first, then additional modules
