# Writing Pxb Scripts

## Getting Started

**Always start from the template**: `templates/pxb-script`

Copy it to `bin/<your-script-name>`, make it executable, and edit from there. The template provides the correct structure, imports, and a representative `opts` block.

### What the Template Gives You

```perl
#! /usr/bin/env perl

use myperl::Pxb;
use autodie ':all';

use Date::Easy;                        # OPTIONAL: remove if not doing date work

const my $CONST => 'Some Constant';    # constants via Const::Fast


opts <<'-';
    [-avD] [-n <num>] { -e <pattern> | <pattern> } <file> [...]
    -a : do a thing (default: don't do that thing)
    -v : be more verbose
    -D : debug mode (implies -v)
    -n : do a thing <num> times
    -e : next arg is the <pattern>, even if it starts with -
    <pattern> : Perl-style regex
    <file>    : one or more files to process
-
$OPT{v} = 1 if $OPT{D};
$OPT{n} //= 1;

my $regex = $OPT{e} // shift // usage_error('must supply regex');
$regex = qr/$regex/;
my @files = map { file($_) } @ARGV or usage_error("must supply at least one file");


sh(cmd => -v => @files);
```

### Adapting the Template

1. **Strip what you don't need**: Remove `use Date::Easy`, unused constants, unused options. Most scripts only need a few options.
2. **Write your `opts` block**: Replace the template's options with your actual options (see opts reference below).
3. **Parse arguments**: Pull positional args from `@ARGV` via `shift`, validate with `usage_error()`.
4. **Write the body**: Use `sh()` for external commands, standard Perl for everything else.
5. **Add helper subs at the bottom**: Local functions go after the main body, in snake_case with Allman bracing.

### Minimal Example (Real Pattern)

A simple script that only needs debug mode and one argument:

```perl
#! /usr/bin/env perl

use myperl::Pxb;
use autodie ':all';


opts <<'-';
    [-D] <dir>
    -D : debug mode
-

my $dir = shift // '.';
$dir = path($dir);

sh(ls => -la => $dir);
```

## What `use myperl::Pxb` Provides

`myperl::Pxb` is a superset. It loads `myperl::Script` (which loads `myperl`), then adds command execution on top. When you `use myperl::Pxb`, you get everything listed here.

### From myperl (core)

Automatically imported pragmas and modules:
- `strict`, `warnings` (FATAL), `utf8`, `feature ':5.14'`
- `Const::Fast` — `const my $X => value;`
- `Scalar::Util` — `blessed`
- `List::Util` — `first`, `max`, `min`, `reduce`, `shuffle`, `sum`
- `List::MoreUtils` — `apply`, `zip`, `uniq`
- `Debuggit` — `debuggit(LEVEL => "message", ...)`

Autoloaded functions (module loads only if called):
- `form()` (Perl6::Form) — formatted text output
- `str2time()` (Date::Parse), `time2str()` (Date::Format)
- `basename()` (File::Basename)
- `menu()` (myperl::Menu)
- `slurp()` — reads a file, defaults to UTF-8
- `prompt()`, `confirm()` — interactive user input
- `title_case()`, `round()`, `expand()`, `unipad()`

Note: `myperl::Script` (and therefore `myperl::Pxb`) uses `NO_SYNTAX => 1`, which skips the heavier syntax modules (CLASS, Syntax::Keyword::Try, Method::Signatures, Date::Easy, Perl6::Gather, etc.) for faster startup. Add them explicitly with `use` if needed.

### From myperl::Script

- **`$ME`** — basename of the script (for error messages)
- **`%OPT`** — hash of parsed command-line option values
- **`opts`** — declarative option/usage parser (see below)
- **`fatal($msg)`** — print `$ME: $msg` to STDERR and exit 1
- **`usage_error($msg)`** — like `fatal` but exits 2 and suggests `-h`
- **`color_msg($color, $msg)`** — colored terminal output (auto-detects TTY)

### From myperl::Pxb

- **`sh()`** — context-sensitive command execution (the main workhorse)
- **`shw()`** — like `sh` but splits output on whitespace instead of lines
- **`bash()`** — the underlying PerlX::bash function (lower-level)
- **`shq()`** — shell-quote a string (wraps in single quotes)
- **`head()`**, **`tail()`** — array slicing utilities (not file reading)
- **`path()`**, **`file()`**, **`dir()`** — Path::Class::Tiny constructors
- **`tempfile()`**, **`tempdir()`** — temporary file/directory creation

## `opts` Reference

The `opts` function parses a heredoc spec to define options, build help text, and parse `@ARGV`. Uses Getopt::Std internally (single-character options only).

### Structure

```perl
opts <<'-';
    <usage_line>
    -X : description of boolean flag
    -Y : description of flag that takes <argument>
    <positional> : description of positional arg
-
```

### Rules

- **First line** is the usage line (shows up in `-h` output).
- **Option lines** start with `-` followed by a single character. If the description contains `<angle brackets>`, the option takes an argument; otherwise it's boolean.
- **Post-option lines** (after the first non-`-` line) are descriptive text shown in help.
- A `-h` option is automatically added.
- Options end up in `%OPT` keyed by their character. `@ARGV` retains positional args.
- Use `<<'-'` (single-quoted delimiter) normally. Use `<<"-"` (double-quoted) only if you need variable interpolation in the spec.

### Common Option Patterns

Nearly every Pxb script follows these conventions:

```perl
# Verbose + debug mode (standard pair)
opts <<'-';
    [-vD] <args>
    -v : be more verbose
    -D : debug mode (implies -v)
-
$OPT{v} = 1 if $OPT{D};

# Option with a default value (use interpolation)
$OPT{n} = 10;
opts <<"-";
    [-n <N>]
    -n : number of items (default: $OPT{n})
-

# Boolean flags
$OPT{y}   # -y flag was passed (truthy) or not (undef)

# Options with arguments
$OPT{f}   # value of -f <file> (string), or undef if not passed
```

### Argument Validation

```perl
# Required positional argument
my $file = shift or usage_error("must supply file");

# Optional with default
my $dir = shift // '.';

# Convert to path objects
$dir = path($dir);                    # generic path
my $f = file($OPT{f});               # file path
my $d = dir('/some/path');            # directory path

# Validate
-e $ref or usage_error("file does not exist");
-d $dest or usage_error("must be a directory");
```

## `sh()` Reference

`sh()` is the primary function for running external commands. It wraps PerlX::bash with context-sensitive return behavior.

### Context Determines Return Value

```perl
# Void context: output goes to terminal
sh(ls => -la => $dir);

# Scalar context: output returned as one string (chomped)
my $hostname = sh('hostname');

# List context: output returned as array of lines (each chomped)
my @files = sh(find => $dir => -type => 'f');

# Word splitting: use shw() instead of sh()
my ($date, $mode, $checksum) = shw(stat => -c => "%Y %f", $file);
```

### Argument Passing

Arguments are passed as a flat list. PerlX::bash handles quoting intelligently:

```perl
# Simple command with flags
sh(rsync => -avz => $src, $dest);

# Path objects are auto-quoted (handles spaces in filenames)
my $f = file("~/My Documents/file.txt");
sh(cat => $f);                         # path objects auto-quoted correctly

# Shell operators as separate string arguments
sh(echo => "foo", '|', cat => );       # pipe
sh(echo => "foo", '>/dev/null');        # redirect
sh(echo => "foo", '2>&1');             # stderr redirect

# Explicit shell quoting with shq()
sh(echo => shq(">not-a-redirect"));

# Run via bash -c for complex shell syntax
sh(bash => -c => "diff <(sort $f1) <(sort $f2)");

# Bash options for the command itself
sh(bash => -c => -O => extglob => $cmd);
```

### Capturing in Different Ways

```perl
# Capture as lines (list context)
my @lines = sh(git => log => '--oneline');

# Capture as string (scalar context)
my $output = sh(cat => $file);

# Capture as words
my @words = shw(stat => -c => "%Y %f %s", $file);

# First N results (head/tail work on arrays, not files)
my @top3 = head 3 => sh(some_cmd => );
my @last2 = tail -2 => sh(some_cmd => );
```

### The `-D` Debug Pattern

When a script has `-D` (debug mode) and the user passes it, `sh()` automatically prints each command to STDERR prefixed with `+` (like `bash -x`). This happens because myperl::Pxb checks `$OPT{D}` internally.

## Other Available Functions

### Path Operations

`path()`, `file()`, and `dir()` all return Path::Class::Tiny objects:

```perl
my $p = path("~/some/file.txt");       # general path
my $f = file("/etc/hosts");            # same thing, semantic hint
my $d = dir("/var/log");               # same thing, semantic hint

$p->slurp;                             # read entire file
$p->spew($content);                    # write entire file
$p->basename;                          # filename component
$p->dirname;                           # directory component
$p->parent;                            # parent as path object
$p->child("subdir");                   # append path component
$p->realpath;                          # resolve symlinks
$p->is_absolute;                       # check if absolute
-e $p; -f $p; -d $p;                   # file tests work normally
```

### Interactive Prompting

```perl
# Yes/no confirmation (returns 1 or 0)
exit unless confirm("Are you sure?");

# Text prompt with default
my $name = prompt("Enter name:", default => "world");
```

### Temp Files

```perl
my $tmp = tempfile;                     # auto-cleaned on exit
$tmp->spew($data);

# Named template, not auto-cleaned
my $log = tempfile(TEMPLATE => "$ME-log.XXXXXX", UNLINK => 0);
```

### Debugging

```perl
debuggit(2 => "variable is:", $var);           # print at debug level 2
debuggit(4 => "structure:", DUMP => \%hash);   # dump data structure at level 4
```

## Troubleshooting

- **Module not found**: Run `bin/myperl-cpm myperl` to install dependencies
- **Encoding issues**: myperl enables utf8 automatically; ensure source files are UTF-8
- **autodie conflicts**: myperl scripts use `autodie`; don't manually check `open()` return values
- **`sh()` errors**: Commands that exit non-zero throw exceptions when using `-e` switch; without it, check `$?` or return value
