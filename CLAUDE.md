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

## Key Files and Directories
- `/bin/t`: Comprehensive test runner with coverage, profiling, and parallel execution
- `/bin/myperl-cpm`: Dependency installer using App::cpm with cpanfile features
- `/perl/myperl.pm`: Core framework providing enhanced Perl environment
- `/perl/myperl/`: Framework modules (Classlet, Script, Pxb, etc.)
- `/cpanfile`: Dependency specifications with feature groups
- `/local/*/`: Host-specific configurations and scripts

## Development Workflow
When working with myperl code:
1. Use TDD: write tests in `perl/myperl/t/` first
2. Run `t myperl` to execute test suite
3. Install new dependencies via `bin/myperl-cpm <feature>`
4. Follow existing patterns in framework modules

## Git Commit Format
When committing changes, use this format:
```
brief summary line (imperative mood, lowercase)

- Bullet point description of key changes
- Use descriptive bullets focusing on "what" and "why"
- Keep lines under 72 characters when possible

🤖 Generated with [Claude Code](https://claude.ai/code) (<model_name>)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Note:** Replace `<model_name>` with the actual Claude model being used (e.g., "Sonnet 4", "Sonnet 4.1", etc.)

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
