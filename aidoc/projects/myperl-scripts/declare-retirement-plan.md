# Retiring myperl::Declare — Migration Plan

## Background

`myperl::Declare` wraps `MooseX::Declare`, which depends on `Devel::Declare` for source-level
manipulation of Perl's `PL_linestr` buffer. `Devel::Declare` is deprecated on CPAN and broken on
Perl 5.34+ — the `class` keyword produces "Couldn't find declarator" or "PL_linestr not long enough"
errors. This also breaks `Method::Signatures`, which inherits from
`Devel::Declare::MethodInstaller::Simple`.

`myperl::Classlet` (Moops-based) and its signature engine (Kavorka) already work correctly and
provide equivalent or superior functionality. The goal is to route everything through the
Moops/Kavorka stack and retire the `Devel::Declare` dependency chain entirely.

## Research Summary

### What depends on Devel::Declare (broken)
- `MooseX::Declare` — provides `class`/`role` keywords in `myperl::Declare`
- `Method::Signatures` — provides `func`/`method` keywords in `myperl.pm`
- `Method::Signatures::Modifiers` — provides `around`/`augment` with sigs in `myperl::Declare`

### What replaces them (working)
- `Moops` — provides `class`/`role` keywords via `Keyword::Simple` (no `Devel::Declare`)
- `Kavorka` — provides `func`/`method`/`classmethod`/modifiers via `Parse::Keyword`
- `myperl::Classlet` — extends Moops with custom attribute sugar (`rw`, `via`, `by`, etc.)

### Kavorka compatibility with Method::Signatures
Nearly drop-in. Of 18 features surveyed, 17 are syntax-identical. One difference:
- `where @ARRAY` (bare array) must become `where \@ARRAY` (array reference)

Features NOT used in the codebase (no porting concern): return types, `before`/`after` modifiers
with sigs, `is ro`/`is copy` traits, nested parameterized types.

### Compile-time installation issue
`Method::Signatures` installs `func` at compile time (via `Begin::Lift`), allowing forward
references: `foo(); func foo { }`. Kavorka installs at **runtime** by default — forward references
fail. Kavorka provides a `begin` trait (`func foo () but begin { }`) that fixes this, but requiring
it on every declaration is unacceptable. Solution: subclass `Kavorka::Sub::Fun` to default to
compile-time installation (override `_build__tmp_name` to return the real qualified name instead of a
temp name, same as the `begin` trait does internally).

### Zydeco (Moops successor) — considered but rejected for now
Zydeco is more opinionated and would require significant rewrites: named params use `*name` instead
of `:$name`, accessed via `$arg->name`; no `func` keyword; no `is alias`; no `augment`. Kavorka is
the clear winner for compatibility. Zydeco remains a long-term option if Moops becomes unmaintained.

### Scope of affected code

**Framework modules that use `class` syntax (need porting to Classlet):**
- `perl/myperl/Google.pm` — ~30 methods, `around` modifier, anonymous `method` in defaults
- `perl/myperl/Menu.pm` — 4 `func` declarations, package-qualified `func menu::status`
- `perl/myperl/Template.pm` — `method` + `func`, custom invocant `$class:`

**Scripts using `func`/`method` at top level (need Kavorka swap):**
- `bin/blogify` (~17 funcs, includes `is alias`)
- `bin/todo` (~8 funcs)
- `bin/pidgin_restore` (~5 funcs)
- `bin/paychecks`, `bin/sql_filter`, `bin/fake_timerdavg`, `bin/fake_timeravg`,
  `bin/blog-wc`, `bin/song-times` (1-3 funcs each)
- `work/` scripts: `qsift/QSift.pm`, `ferry/push` (has `where` clauses),
  `leadid/update_lec_perms`, `ceflow/mxd-bench/` (has `augment`)

**Scripts using plain `use myperl` but NOT class/func syntax:**
These just pay unnecessary load-time cost for `myperl::Declare` + `Method::Signatures`. They need
only `NO_SYNTAX => 1` or a switch to `myperl::Pxb`/`myperl::Script`.

**Test files affected:**
- `t/args.t` — tests 14-15 test `NO_SYNTAX => 0` override (currently failing)
- `t/class.t` — tests MooseX::Declare class snippets
- `t/inside.t`, `t/outside.t` — snippet-based tests including `class Foo {}`
- `t/classlet.t` — Classlet tests (already working; needs expansion)
- `t/Test/myperl.pm` — `%ALL_SNIPPETS` references `class Foo {}` via Declare path

## Implementation Plan

### Phase 0: Prep work — improve Classlet test coverage

**Goal**: Ensure confidence in the Classlet/Kavorka stack before relying on it more broadly.

**TDD tasks:**
- Add `classmethod` tests to `classlet.t` (currently imported but untested)
- Add method signature tests with types, named params, defaults, optionals
- Add `where` clause tests (block form and arrayref form)
- Add `is alias` test
- Add method modifier tests (`around`, `before`, `after`) inside Classlet classes
- Add custom invocant test (`$class:` syntax)
- Verify `func` works via direct `use Kavorka qw(func)` in a test

**No production code changes in this phase.** Only new tests.

### Phase 1: Create compile-time `func` via Kavorka subclass

**Goal**: Drop-in replacement for `Method::Signatures`' `func` and `method` keywords.

**TDD tasks:**
1. Write test: `func foo { 42 } is(foo(), 42)` — basic func works
2. Write test: `foo(); func foo { 42 }` — forward reference works (compile-time install)
3. Write test: `method bar ($self: $x) { $x + 1 }` — method works outside class
4. Write test: verify `func` with types, defaults, named params, `is alias`

**Implementation:**
- Create `perl/myperl/Kavorka/FuncBegin.pm` — subclass of `Kavorka::Sub::Fun` that overrides
  `_build__tmp_name` to return `$self->qualified_name` (same logic as the `begin` trait)
- Create `perl/myperl/Kavorka/MethodBegin.pm` — same for methods outside classes
- Register these as the handlers for `func`/`method` when imported via myperl

### Phase 2: Swap Method::Signatures for Kavorka in myperl.pm

**Goal**: All `use myperl` scripts get `func`/`method` from Kavorka instead of Method::Signatures.

**TDD tasks:**
1. Update `t/args.t` — existing tests should still pass with the new backend
2. Write test: verify `func` forward reference works via `use myperl`
3. Write test: snippet tests in `%ALL_SNIPPETS` for `func` and `method`

**Implementation:**
- In `myperl.pm`, replace `'Method::Signatures' => 20111125 =>` with the Kavorka import
  (using the FuncBegin/MethodBegin subclasses from Phase 1)
- Run full test suite; fix any regressions

**Risk**: This is the highest-risk change — it affects every `use myperl` script. Thorough testing
is essential. Consider running the affected bin/ scripts manually to verify.

### Phase 3: Port framework modules from Declare to Classlet

**Goal**: Migrate `Google.pm`, `Menu.pm`, `Template.pm` off MooseX::Declare.

**Order** (easiest to hardest):
1. `Menu.pm` — only uses `func`, no classes. May just need the Kavorka swap from Phase 2.
2. `Template.pm` — small, 2 functions, custom invocant
3. `Google.pm` — large, ~30 methods, `around` modifier, anonymous `method` in defaults, union
   types, custom types. This is the big one.

**TDD tasks for each module:**
1. Run existing tests, verify baseline
2. Port module to Classlet
3. Run tests, verify no regressions
4. Add any new tests needed for features not previously covered

**Special attention for Google.pm:**
- `around when ()` — Kavorka `around` auto-provides `$next` + `$self`; syntax differs slightly
- `default => method { ... }` — verify anonymous `method` works as coderef in Kavorka
- Union types `Int|Str` — should work but verify
- `MooseX::ClassAttribute`, `MooseX::StrictConstructor`, `MooseX::Has::Sugar` — verify equivalents
  exist in Moops/Classlet or add them

### Phase 4: Update myperl.pm to stop loading Declare

**Goal**: Remove `myperl::Declare` from the default import chain.

**Implementation:**
- Remove `'myperl::Declare'` from the `unless $NO_SYNTAX` import block in `myperl.pm`
- Remove `'Method::Signatures'` (already done in Phase 2, but verify it's gone)
- Update the `unless $NO_SYNTAX` block to import Kavorka modifiers if needed
- Update `t/args.t` tests 14-15: either fix them to test Classlet's `class` keyword, or remove
  them if the `NO_SYNTAX => 0` + `ONLY` combo no longer makes sense
- Update `%ALL_SNIPPETS` in `Test/myperl.pm`: change `class Foo {}` snippet to use the
  Classlet/Moops path
- Update `t/inside.t`, `t/outside.t`, `t/class.t` accordingly
- Run full test suite

### Phase 5: Deprecate and remove myperl::Declare

**Goal**: Clean removal with no dangling references.

**Steps:**
1. Add a deprecation warning to `myperl::Declare::import`:
   `warn "myperl::Declare is deprecated; use myperl::Classlet instead\n"`
2. Leave it in place for one release cycle (or a reasonable grace period) to catch any
   external code that imports it directly
3. After grace period: delete `perl/myperl/Declare.pm`
4. Remove `MooseX::Declare`, `Method::Signatures`, `Method::Signatures::Modifiers` from `cpanfile`
   (keep `Devel::Declare` only if something else still needs it; otherwise remove too)
5. Update `aidoc/projects/myperl-scripts/modifying-myperl.md` — remove Declare references,
   update architecture diagram
6. Update `aidoc/projects/myperl-scripts/README.md` — remove Declare from repository layout

### Phase 6: Audit and clean up scripts outside this repo

**Goal**: Catch any `work/` scripts or other repos that still depend on the old path.

**Tasks:**
- Grep `~/work/` for `use myperl::Declare`, `use MooseX::Declare`, `use Method::Signatures`
- Port any stragglers (most should just work after Phase 2)
- Special attention to `work/ferry/push` (`where @ARRAY` syntax needs `\@ARRAY`)
- Special attention to `work/ceflow/mxd-bench/` (`augment` modifier)

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Kavorka `func` compile-time subclass doesn't work as expected | Medium | High | Phase 1 is entirely dedicated to this; TDD before touching production |
| Subtle signature behavior differences break scripts | Low | Medium | Kavorka syntax is nearly identical; test thoroughly in Phase 2 |
| `around` modifier syntax difference causes Google.pm bugs | Medium | Medium | Write targeted tests in Phase 0; careful manual review in Phase 3 |
| Anonymous `method` in attribute defaults behaves differently | Low | Medium | Test explicitly in Phase 0 |
| Moops has its own bugs on certain Perl versions | Low | High | Moops already works (vim-session proves it); test on target Perls |
| Scripts outside this repo break silently | Medium | Low | Phase 6 audit; deprecation warning in Phase 5 catches stragglers |
| Perl 5.14 perlbrew environments | Low | Low | Moops/Kavorka require 5.14; should be fine |

## Open Questions

1. **Do any of the `MooseX::*` modules loaded by Declare have Classlet equivalents?**
   `MooseX::ClassAttribute`, `MooseX::StrictConstructor`, `MooseX::Has::Sugar` — need to verify
   these work under Moops, or find alternatives, before porting Google.pm.

2. **Should `use myperl` (without NO_SYNTAX) switch to loading Classlet instead of Declare?**
   Currently it loads Declare for the `class`/`role` keywords. After Phase 4, those keywords would
   only be available via explicit `use myperl::Classlet`. This changes the semantics of plain
   `use myperl`. Need to decide if that's acceptable or if `use myperl` should auto-load Classlet.

3. **Is the `ceflow/mxd-bench/` augment usage still needed?**
   It looks like a benchmark, not production code. If so, it can be left as-is or dropped.

4. **Package-qualified `func` (e.g. `func menu::status`)** — confirmed compatible in Kavorka,
   but needs a test.

## Success Criteria

- `t myperl` passes with zero failures (including the currently-failing tests 14-15 in args.t)
- All `bin/` scripts that use `func`/`method` continue to work identically
- `vim-session` continues to work (already on Classlet; should be unaffected)
- No script loads `Devel::Declare` at runtime
- `perl/myperl/Declare.pm` is deleted
- Documentation updated to reflect new architecture
