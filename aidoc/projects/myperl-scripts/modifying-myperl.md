# Modifying myperl

## Before You Touch Anything

### Run the tests first

**Always run the full test suite before making any changes:**

```
t myperl
```

This establishes a baseline. If any tests fail before your changes, you know those failures are pre-existing and not caused by your work. If you skip this step, you won't be able to tell whether a failing test is your fault or not.

The full suite runs in about 4 seconds, so there's no reason to skip it. Run `t -h` for additional options (e.g. `t -v myperl` for verbose output).

### Use TDD

**Test-driven development is required for all myperl changes.** Use the `/x-tdd` skill to enforce the discipline.

myperl is used by nearly every script in this repository. If it breaks, everything breaks. TDD provides the confidence that changes work correctly and don't introduce regressions. The workflow is:

1. Run `t myperl` to establish baseline (all tests pass)
2. Write a failing test for the new behavior
3. Run `t myperl` to verify the test fails (and only your new test fails)
4. Write the minimal code to make the test pass
5. Run `t myperl` to verify all tests pass
6. Refactor if needed, re-running tests after each change

## Module Architecture

The framework is layered. Each layer builds on the one below it:

```
myperl::Pxb          command execution (sh, shw) + path utilities
    |
myperl::Script       script infrastructure ($ME, %OPT, opts, fatal)
    |
myperl               core imports (strict, warnings, utf8, utilities)
    |
myperl::Declare      class syntax (MooseX::Declare integration)
myperl::Classlet     enhanced OOP keywords (rw, via, by)
```

### `perl/myperl.pm` — Core Framework

**What it does**: The `import` method is the heart. It uses `Import::Into` and `Sub::Install` to push pragmas, modules, and utility functions into the caller's namespace.

**Three import tiers**:
- **Always imported**: `strict`, `warnings` (FATAL), `utf8`, `feature ':5.14'`, `Const::Fast`, `Scalar::Util`, `List::Util`, `List::MoreUtils`, `Debuggit`
- **Imported unless `NO_SYNTAX`**: `CLASS`, `Syntax::Keyword::Try`, `Date::Easy`, `Path::Class::Tiny`, `Perl6::Gather`, `myperl::Declare`, `Method::Signatures`
- **Autoloaded** (module loads only when function is called): `form`, `str2time`, `time2str`, `basename`, `menu`, `glob`

**Utility functions** defined directly in myperl.pm: `title_case`, `round`, `slurp`, `expand`, `unipad`, `prompt`, `confirm`

**Import arguments** (`use myperl DEBUG => 2`, `NO_SYNTAX => 1`, `ONLY => [...]`, etc.) are handled via `%PASS_THRU` and `%PASS_UNLESS` hashes at the top of the file, then dispatched in the `import` sub.

**Where to make changes**:
- Adding a new always-imported module: add to the `import_list_into` call in `import` (the first one, before the `unless $NO_SYNTAX` block)
- Adding a new syntax module: add to the second `import_list_into` call (the one gated by `$NO_SYNTAX`)
- Adding a new autoloaded function: add to the `%autoload_funcs` hash
- Adding a new utility function: define the sub in myperl.pm, add its name to the `foreach` loop that calls `Sub::Install::install_sub`
- Adding a new import argument: add to `%PASS_THRU` or `%PASS_UNLESS` depending on behavior

### `perl/myperl/Script.pm` — Script Infrastructure

**What it does**: Provides the command-line script essentials. Can only be loaded from `package main`.

**Exports**: `$ME`, `%OPT`, `opts`, `fatal`, `usage_error`, `color_msg`

**Key details**:
- Sets up UTF-8 on STDIN/STDOUT/STDERR and enables autoflush
- Passes through to `myperl::import` with `NO_SYNTAX => 1` (for faster startup)
- `opts` parses a heredoc spec using `Getopt::Std` (single-character options only)
- Any args passed to `use myperl::Script` (like `DEBUG => 2`) are forwarded to myperl

**Where to make changes**:
- Adding a new exported variable/function: add to `@EXPORT` and define the sub
- Changing option parsing behavior: modify the `opts` sub
- Changing error formatting: modify `fatal` or `usage_error`

### `perl/myperl/Pxb.pm` — Command Execution Layer

**What it does**: Builds on Script by adding PerlX::bash (the `bash` function for running shell commands) and Path::Class::Tiny (path/file/dir constructors). Provides `sh()` and `shw()` as ergonomic wrappers around `bash`.

**Exports**: Everything from PerlX::bash (`bash`, `shq`, `pwd`, `head`, `tail`, `tempfile`), everything from Path::Class::Tiny (`path`, `file`, `dir`, `tempdir`), plus its own `sh` and `shw`.

**Key details**:
- When loaded from `main`, passes through to `myperl::Script::import`
- When loaded from another package, exports the `Path` type (for use in Moose/CLASS attributes)
- `sh()` is context-sensitive: void context runs the command, scalar returns a string, list returns lines
- `shw()` always splits on whitespace (words)
- The `-D` debug feature: when `$OPT{D}` is set, `_dash_x` prints each command to STDERR before running it

**Where to make changes**:
- Adding a new shell utility function: define it in Pxb.pm and add to `@EXPORT`
- Changing how `sh` handles context: modify the `sh` or `_sh` subs
- Changing debug output format: modify `_dash_x`

### `perl/myperl/Classlet.pm` — Enhanced OOP

**What it does**: Extends Moops to provide a cleaner class syntax with attribute keywords.

**Keywords**: `rw`, `via`, `by`, `per`, `as`, `set`, `clear`, `check`, `Array`, `Hash`, `builds`

**Key details**:
- `_pre_has` intercepts Moose's `has` to inject defaults (e.g. `is => 'ro'`, `required => 1`) and handle native traits
- `builds` is syntactic sugar for `has` with `lazy => 1`
- `with` is context-sensitive: in list context it's Moose role composition, in scalar context it's the `default` property

**Where to make changes**:
- Adding a new attribute keyword: define the sub in `myperl::Classlet::keywords`, add to `@EXPORT`
- Changing default attribute behavior: modify `_pre_has`
- Adding a new `has` wrapper (like `builds`): define the sub and add a `_wrap_caller_func` call in `import`

### `perl/myperl/Declare.pm` — Class Syntax

**What it does**: Integrates MooseX::Declare so you can write `class Foo { ... }` and `role Bar { ... }`. Loads the full myperl import set plus Moose ecosystem modules into classes.

**Rarely modified.** Changes here would involve adding new modules that should be available inside every class declaration.

## Test Infrastructure

### Test Files

Each module area has its own test file(s) in `perl/myperl/t/`:

| Test file | What it covers |
|-----------|---------------|
| `load.t` | Basic `use_ok` for all modules |
| `inside.t` | Syntax snippets work inside `use myperl` |
| `outside.t` | Syntax snippets work outside classes (in main) |
| `args.t` | Import arguments (DEBUG, NO_SYNTAX, ONLY, NoFatalWarns) |
| `script.t` | myperl::Script: opts parsing, help, fatal, usage_error, UTF-8 |
| `pxb.t` | myperl::Pxb: sh/shw, bash exports, -D debug mode, Path type |
| `classlet.t` | Classlet keywords: has, builds, rw, via, by, per, Array, Hash |
| `autoload.t` | Autoloaded functions load their modules on first call |
| `round.t` | `round()` function |
| `title_case.t` | `title_case()` function |
| `unipad.t` | `unipad()` function |
| `expand.t` | `expand()` function |
| `prompt.t` | `prompt()` and `confirm()` functions |
| `dates.t` | Date::Easy integration |
| `utf8.t` | UTF-8 handling |
| `glob.t` | Custom `glob()` override |
| `list_utils.t` | List::Util and List::MoreUtils imports |
| `scalar_utils.t` | Scalar::Util imports |
| `class.t` | CLASS module integration |
| `redefine.t` | Module redefine functionality |
| `templ.t` | myperl::Template |
| `use_for.t` | Module loading utilities |
| `perl-w.t` | `perl -w` compatibility |

### Test Helper: `Test::myperl`

Located at `perl/myperl/t/Test/myperl.pm`. Provides functions for testing Perl snippets in a subprocess:

```perl
use File::Basename;
use lib dirname($0);
use Test::myperl;
```

**Key functions**:

- **`perl_output_is($name, $expected, $code, @args)`** — runs `$code` as a Perl one-liner, asserts STDOUT matches `$expected`
- **`perl_no_output($name, $code, @args)`** — asserts the code produces no STDOUT
- **`perl_error_is($name, $expected, $code, @args)`** — asserts STDERR matches `$expected` (string or regex)
- **`perl_no_error($name, $code, @args)`** — asserts the code produces no STDERR
- **`perl_combined_is($name, $expected, $code, @args)`** — asserts combined STDOUT+STDERR
- **`perl_exit_is($name, $expected, $code, @args)`** — asserts exit code
- **`test_snippet($snippet)`** — checks a snippet against `%ALL_SNIPPETS` (used by inside.t/outside.t)

The `@args` are passed as command-line arguments to the Perl subprocess (useful for testing `opts` parsing, e.g. `'-a'`, `'-c'`, `'foo'`).

**Snippet hashes** define code fragments and their expected behavior:
- `%COMMON_SNIPPETS` — basics (strict, warnings, utf8, say, given/when)
- `%CLASSLET_SNIPPETS` — Classlet-specific syntax
- `%ALL_SNIPPETS` — everything including advanced syntax (Const::Fast, Path::Class::Tiny, class, try/catch, etc.)

### Writing a New Test

**For a utility function** (like `round`, `title_case`):

```perl
use myperl;

use Test::Most 0.25;


# Test the function directly
is my_func("input"), "expected", "description of test case";

# Test edge cases
is my_func(""), "", "handles empty string";
throws_ok { my_func(undef) } qr/error/, "rejects undef";


done_testing;
```

**For a Script/Pxb feature** (needs subprocess testing):

```perl
use Test::Most 0.25;

use File::Basename;
use lib dirname($0);
use Test::myperl;


perl_output_is( "description", <<OUT, <<'END', qw< -a arg1 > );
expected output
OUT
    use myperl::Pxb;
    opts <<"-";
        [-a] <arg>
        -a : some flag
-
    say "something using $OPT{a} and @ARGV";
END


done_testing;
```

**For a new import or syntax feature**:

Add the snippet to `%ALL_SNIPPETS` (or `%CLASSLET_SNIPPETS`) in `Test::myperl`, then the existing `inside.t` and `outside.t` tests will automatically verify it compiles correctly.

## Common Modification Scenarios

### Adding a new utility function to myperl

1. Write failing test in a new or existing test file under `perl/myperl/t/`
2. Define the sub in `perl/myperl.pm`
3. Add the function name to the `foreach` loop near line 62 that calls `Sub::Install::install_sub`
4. If it depends on a CPAN module, use lazy loading (`require Module` inside the sub body) to avoid startup cost
5. Run `t myperl` to verify

### Adding a new autoloaded function

1. Write failing test (use `autoload.t` pattern: verify module not loaded, call function, verify module now loaded)
2. Add to the `%autoload_funcs` hash in `perl/myperl.pm` (maps module name to function name)
3. Run `t myperl` to verify

### Adding a new module to the always-imported set

1. Add a snippet test to `%ALL_SNIPPETS` in `Test::myperl` (if it provides syntax)
2. Add the module to the first `import_list_into` call in `myperl.pm`'s `import` sub
3. If it needs a minimum version: `'Module::Name' => 1.23 =>`
4. If it needs specific imports: `'Module::Name' => [ qw< func1 func2 > ]`
5. Run `t myperl` to verify (inside.t/outside.t will pick it up automatically)

### Adding a new export to Script or Pxb

1. Write a subprocess test in `script.t` or `pxb.t` using `perl_output_is` / `perl_no_error`
2. Define the sub in the appropriate module
3. Add to `@EXPORT` in that module
4. Run `t myperl` to verify

### Adding a new Classlet keyword

1. Write test in `classlet.t` (define a class using the keyword, test the resulting behavior)
2. Add a snippet to `%CLASSLET_SNIPPETS` in `Test::myperl`
3. Define the sub in `myperl::Classlet::keywords`
4. Add to `@EXPORT` in that package
5. If it wraps `has`, add a `_wrap_caller_func` call in the `import` sub
6. Run `t myperl` to verify

### Fixing a bug

1. Write a test that reproduces the bug (it should fail)
2. Fix the bug
3. Run `t myperl` to verify the fix and check for regressions

## Dependencies

When a new feature requires a CPAN module:

- **For utility functions**: Use lazy loading (`require Module` inside the sub). This keeps startup fast since the module only loads if the function is actually called.
- **For always-imported modules**: Add directly to the `import_list_into` call. These load at `use myperl` time.
- **For the cpanfile**: Add the dependency to `/cpanfile` under the appropriate feature group, then install with `bin/myperl-cpm <feature>`.
